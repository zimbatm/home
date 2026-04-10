#!/usr/bin/env bash
# Extract per-agent token costs from workflow transcripts and optionally
# attach as git notes to correlated commits.
#
# Usage:
#   .claude/workflows/token-cost.sh                    # table of all agents
#   .claude/workflows/token-cost.sh --notes            # attach git notes to commits
#   .claude/workflows/token-cost.sh --by-role          # per-role aggregate with WIDE/DRY flags
#   .claude/workflows/token-cost.sh --workflow=wf_xxx  # one workflow only
set -euo pipefail

PROJ_SLUG=$(pwd | tr / -)
# Pick session by newest agent transcript, not session-dir mtime — dir mtime
# only updates on direct-child writes, so a long-running grind session loses
# to a short side-workflow even when its transcripts are fresher.
# (Subshell drops pipefail: ls SIGPIPEs into head -1 with thousands of files.)
SESSION_DIR="${SESSION_DIR:-$(set +o pipefail; ls -t ~/.claude/projects/$PROJ_SLUG/[0-9a-f]*-*/subagents/workflows/*/agent-*.jsonl 2>/dev/null | head -1 | sed 's|/subagents/.*||')}"
ARG="${1:-}"
WF_FILTER=""
ATTACH_NOTES=false
BY_ROLE=false
case "$ARG" in
  --workflow=*) WF_FILTER="${ARG#--workflow=}" ;;
  --notes) ATTACH_NOTES=true ;;
  --by-role) BY_ROLE=true ;;
esac

python3 - "$SESSION_DIR" "$WF_FILTER" "$ATTACH_NOTES" "$BY_ROLE" <<'PY'
import sys, json, re, subprocess, glob, os, statistics

session_dir, wf_filter, attach, by_role = sys.argv[1], sys.argv[2], sys.argv[3] == "true", sys.argv[4] == "true"
pattern = f"{session_dir}/subagents/workflows/{wf_filter or '*'}/agent-*.jsonl"

# Any all-caps role word after "You are [the/a/an] "; Triage/Merge title-case as fallback.
ROLE_RE = re.compile(r'You are (?:the |an? )?([A-Z][A-Z-]{2,}|Triage|Merge)\b')
ITEM_RE = re.compile(r'Item: backlog/(?:\S*/)?([\w.-]+)\.md|grind/backlog/([\w.-]+)|Round (\d+)')

rows = []
for path in sorted(glob.glob(pattern)):
    role, item, tokens = "?", "?", {"in": 0, "out": 0, "cache_r": 0, "cache_w": 0}
    first_user = True
    with open(path) as f:
        for line in f:
            try: d = json.loads(line)
            except: continue
            msg = d.get("message", {})
            if first_user and msg.get("role") == "user":
                first_user = False
                content = msg.get("content", "")
                if isinstance(content, list):
                    content = " ".join(c.get("text","") for c in content if isinstance(c,dict))
                if m := ROLE_RE.search(content): role = m.group(1).upper()
                if m := ITEM_RE.search(content):
                    item = m.group(1) or m.group(2) or f"r{m.group(3)}"
            u = d.get("message", {}).get("usage")
            if u:
                tokens["in"] += u.get("input_tokens", 0)
                tokens["out"] += u.get("output_tokens", 0)
                tokens["cache_r"] += u.get("cache_read_input_tokens", 0)
                tokens["cache_w"] += u.get("cache_creation_input_tokens", 0)
    total = tokens["in"] + tokens["out"] + tokens["cache_w"]  # cache_r is "free-ish"
    rows.append((role, item, total, tokens, os.path.getmtime(path)))

# Sonnet list pricing per 1M tokens; override via TOKEN_COST_RATES env
# (format: "in,out,cache_w,cache_r" e.g. "3.00,15.00,3.75,0.30")
rates = dict(zip(["in","out","cache_w","cache_r"],
                 map(float, os.environ.get("TOKEN_COST_RATES","3.00,15.00,3.75,0.30").split(","))))
def cost(t):
    return sum(t[k]/1e6 * rates[k] for k in rates)

if by_role:
    # Per-role aggregates with the implementer median as the yardstick.
    # An agent paying ≥2× the implementer median is spending its budget on
    # "decide what to do"; one filing 0 across multiple runs is dry.
    # `filed` counts backlog/* additions in commits whose subject names the
    # role — proxy, but consistent (specialists commit "<role> rN: …").
    log = subprocess.run(
        ["git", "log", "--format=SUBJ %s", "--diff-filter=A", "--name-only",
         "origin/main", "--", "backlog/"],
        capture_output=True, text=True).stdout
    filed = {}
    cur_role = None
    for line in log.splitlines():
        if line.startswith("SUBJ "):
            m = re.match(r'SUBJ (\w+)[\s/-]+r\d+\b', line)
            cur_role = m.group(1).upper() if m else None
        elif line.startswith("backlog/") and not line.startswith("backlog/tried/"):
            if cur_role: filed[cur_role] = filed.get(cur_role, 0) + 1
    by = {}
    for role, item, total, t, _ in rows:
        by.setdefault(role, []).append((total, cost(t)))
    impl_totals = [t for t, _ in by.get("IMPLEMENTER", [(1,0)])]
    impl_med = statistics.median(impl_totals)
    print(f"{'role':<12} {'runs':>5} {'med_billable':>12} {'×impl_med':>9} "
          f"{'p90':>12} {'$total':>9} {'filed':>6} {'/run':>6}  flag")
    print("-" * 92)
    NONFILERS = {"IMPLEMENTER","TRIAGE","META","MERGE","REFACTOR","?"}
    for role in sorted(by, key=lambda r: -statistics.median([t for t,_ in by[r]])):
        runs = by[role]; totals = sorted(t for t,_ in runs)
        med = statistics.median(totals)
        p90 = totals[min(int(len(totals)*0.9), len(totals)-1)]
        ratio = med / impl_med if impl_med else 0
        f = filed.get(role, 0)
        rate = f/len(runs) if role not in NONFILERS else None
        flag = []
        if role != "IMPLEMENTER" and ratio >= 2.0: flag.append("WIDE")
        if rate is not None and len(runs) >= 3 and rate < 0.5: flag.append("DRY")
        print(f"{role:<12} {len(runs):>5} {med:>12,.0f} {ratio:>8.1f}× "
              f"{p90:>12,.0f} {sum(c for _,c in runs):>9.2f} "
              f"{f if rate is not None else '-':>6} "
              f"{f'{rate:.1f}' if rate is not None else '   -':>6}  "
              f"{' '.join(flag) or '-'}")
    print("-" * 92)
    print(f"impl_med = {impl_med:,.0f} billable; "
          f"WIDE = med ≥2× impl_med; DRY = ≥3 runs, <0.5 filed/run")
    sys.exit(0)

rows.sort(key=lambda r: -r[2])
print(f"{'role':<12} {'item':<40} {'billable':>10} {'$cost':>8} {'in':>8} {'out':>8} {'cache_w':>10} {'cache_r':>12}")
print("-" * 114)
for role, item, total, t, _ in rows:
    print(f"{role:<12} {item:<40} {total:>10,} {cost(t):>8.2f} {t['in']:>8,} {t['out']:>8,} {t['cache_w']:>10,} {t['cache_r']:>12,}")
grand = sum(r[2] for r in rows)
grand_cost = sum(cost(r[3]) for r in rows)
print("-" * 114)
print(f"{'TOTAL':<12} {len(rows):<40} {grand:>10,} {grand_cost:>8.2f}")

if attach:
    # Correlate IMPLEMENTER items to merge commits, attach git notes
    merges = subprocess.run(
        ["git", "log", "--merges", "--format=%H %s"],
        capture_output=True, text=True, cwd=os.getcwd()
    ).stdout.splitlines()
    # Iterate merges newest-first; each claims the newest unmatched session
    # whose slug appears in its subject. Prevents recurring items (e.g.
    # housekeeping-refactor-cadence with 70 rows) from all overwriting the
    # same most-recent merge — each merge gets ≤1 session, each session ≤1 merge.
    impl = sorted(((i, r) for i, r in enumerate(rows)
                   if r[0] == "IMPLEMENTER" and r[1] != "?"),
                  key=lambda x: -x[1][4])  # newest mtime first
    consumed = set()
    for line in merges:
        sha, subj = line.split(" ", 1)
        for idx, (role, item, total, t, _) in impl:
            if idx in consumed or item not in subj: continue
            consumed.add(idx)
            note = (f"tokens: {total:,} · ~${cost(t):.2f} "
                    f"(in={t['in']:,} out={t['out']:,} cache_w={t['cache_w']:,} cache_r={t['cache_r']:,})")
            subprocess.run(
                ["git", "notes", "--ref=tokens", "add", "-f", "-m", note, sha],
                capture_output=True, cwd=os.getcwd()
            )
            print(f"  → noted {sha[:8]} ${cost(t):>6.2f} {subj[:50]}", file=sys.stderr)
            break
PY
