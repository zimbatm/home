"""sem-grep: NPU-resident embedding index over the assise repos.

bge-small-en-v1.5 (384-dim) on OpenVINO; sqlite+blob store under
$XDG_STATE_HOME/sem-grep; brute-force cosine (corpus ~2k files, no
faiss). Wrapper at packages/sem-grep/default.nix sets env + model path.
NPU co-residency with wake-listen's Silero and embed-vs-ripgrep recall
are post-deploy falsification targets — see backlog/adopt-sem-grep.md.
"""
import argparse
import json
import os
import sqlite3
import subprocess
import sys
import time

import numpy as np
import openvino as ov
from transformers import AutoTokenizer

MODEL = os.environ["SEM_GREP_MODEL"]
DEVICE = os.environ.get("SEM_GREP_DEVICE", "NPU")
STATE = os.environ["SEM_GREP_STATE"]
REPOS = [p for p in os.environ["SEM_GREP_REPOS"].split(":") if os.path.isdir(p)]
DB = os.path.join(STATE, "index.db")
DIM = 384
CHUNK_LINES, STRIDE = 24, 12
MAX_LEN = 256  # tokens; bge cap is 512 but shorter = faster, fits more on NPU
BATCH = 8
SKIP_EXT = {".png", ".jpg", ".jpeg", ".gif", ".pdf", ".age", ".bin", ".svg",
            ".lock", ".gz", ".zst", ".woff", ".woff2", ".ttf", ".ico"}


def load_embedder():
    tok = AutoTokenizer.from_pretrained(MODEL)
    core = ov.Core()
    net = core.compile_model(f"{MODEL}/openvino_model.xml", DEVICE)
    out = net.outputs[0]
    in_names = {p.any_name for p in net.inputs}

    def embed(texts):
        # max_length padding → static seq dim; NPU prefers fixed shapes.
        enc = tok(texts, padding="max_length", truncation=True,
                  max_length=MAX_LEN, return_tensors="np")
        res = net({k: v for k, v in enc.items() if k in in_names})[out]
        # mean-pool over token axis, masked by attention, then L2-normalise
        mask = enc["attention_mask"][..., None].astype(np.float32)
        pooled = (res * mask).sum(axis=1) / np.clip(mask.sum(axis=1), 1e-9, None)
        n = np.clip(np.linalg.norm(pooled, axis=1, keepdims=True), 1e-9, None)
        return (pooled / n).astype(np.float32)
    return embed


def db():
    os.makedirs(STATE, exist_ok=True)
    con = sqlite3.connect(DB)
    con.executescript("""
      CREATE TABLE IF NOT EXISTS files(
        repo TEXT, path TEXT, sha TEXT, PRIMARY KEY(repo, path));
      CREATE TABLE IF NOT EXISTS chunks(
        id INTEGER PRIMARY KEY, repo TEXT, path TEXT, line INTEGER, vec BLOB);
      CREATE INDEX IF NOT EXISTS chunks_rp ON chunks(repo, path);
    """)
    return con


def git_tracked(repo):
    """Yield (path, blob_sha) for text-ish tracked files."""
    out = subprocess.run(["git", "-C", repo, "ls-files", "-s"],
                         capture_output=True, text=True, check=True).stdout
    for ln in out.splitlines():
        meta, path = ln.split("\t", 1)  # <mode> <sha> <stage>\t<path>
        sha = meta.split()[1]
        if os.path.splitext(path)[1].lower() in SKIP_EXT:
            continue
        yield path, sha


def chunks_of(repo, path):
    full = os.path.join(repo, path)
    try:
        if os.path.getsize(full) > 256 * 1024:
            return
        with open(full, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except (OSError, UnicodeDecodeError):
        return
    i = 0
    while i < max(1, len(lines)):
        body = "\n".join(lines[i:i + CHUNK_LINES]).strip()
        if body:
            yield i + 1, body
        if i + CHUNK_LINES >= len(lines):
            break
        i += STRIDE


def cmd_index(_args):
    con = db()
    embed = load_embedder()
    n_new = n_skip = 0
    for repo in REPOS:
        prev = dict(con.execute(
            "SELECT path, sha FROM files WHERE repo=?", (repo,)))
        live = set()
        for path, sha in git_tracked(repo):
            live.add(path)
            if prev.get(path) == sha:
                n_skip += 1
                continue
            con.execute("DELETE FROM chunks WHERE repo=? AND path=?",
                        (repo, path))
            batch = list(chunks_of(repo, path))
            for j in range(0, len(batch), BATCH):
                part = batch[j:j + BATCH]
                vecs = embed([t for _, t in part])
                con.executemany(
                    "INSERT INTO chunks(repo,path,line,vec) VALUES(?,?,?,?)",
                    [(repo, path, ln, vecs[k].tobytes())
                     for k, (ln, _) in enumerate(part)])
            con.execute("INSERT OR REPLACE INTO files VALUES(?,?,?)",
                        (repo, path, sha))
            n_new += 1
        for path in set(prev) - live:
            con.execute("DELETE FROM chunks WHERE repo=? AND path=?",
                        (repo, path))
            con.execute("DELETE FROM files WHERE repo=? AND path=?",
                        (repo, path))
        con.commit()
    print(f"sem-grep: indexed {n_new} changed, skipped {n_skip} unchanged → {DB}",
          file=sys.stderr)


def cmd_query(args):
    con = db()
    rows = con.execute("SELECT repo, path, line, vec FROM chunks").fetchall()
    if not rows:
        print("sem-grep: index empty — run `sem-grep index` first",
              file=sys.stderr)
        sys.exit(1)
    embed = load_embedder()
    # bge s2p retrieval prefix on the query side only
    q = embed(["Represent this sentence for searching relevant passages: "
               + args.text])[0]
    mat = np.frombuffer(b"".join(r[3] for r in rows),
                        dtype=np.float32).reshape(-1, DIM)
    scores = mat @ q
    top = np.argsort(-scores)[: args.n]
    home = os.path.expanduser("~") + "/"
    for i in top:
        repo, path, line, _ = rows[i]
        loc = os.path.join(repo, path).replace(home, "~/", 1)
        print(f"{scores[i]:.3f}  {loc}:{line}")
    # falsification log → feeds the embed-vs-ripgrep recall eval
    try:
        with open(os.path.join(STATE, "evals.jsonl"), "a") as f:
            f.write(json.dumps({
                "ts": time.time(), "q": args.text,
                "top": [f"{rows[i][1]}:{rows[i][2]}" for i in top[:5]],
            }) + "\n")
    except OSError:
        pass


def main():
    ap = argparse.ArgumentParser(prog="sem-grep")
    sub = ap.add_subparsers(dest="cmd")
    sub.add_parser("index").set_defaults(fn=cmd_index)
    qp = sub.add_parser("query")
    qp.add_argument("-n", type=int, default=10)
    qp.add_argument("text")
    qp.set_defaults(fn=cmd_query)
    # bare `sem-grep "<text>"` → query
    argv = sys.argv[1:]
    if argv and argv[0] not in {"index", "query", "-h", "--help"}:
        argv = ["query", *argv]
    args = ap.parse_args(argv)
    if not args.cmd:
        ap.print_help(sys.stderr)
        sys.exit(2)
    args.fn(args)


if __name__ == "__main__":
    main()
