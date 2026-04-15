# adopt-log-sem — journald into sem-grep's NPU index

## what

`sem-grep log "<query>"` — new verb. Nightly user timer dumps
`journalctl --user -o json -S -7d` + `--system` (priority≤warning),
chunks per `_SYSTEMD_UNIT` per hour, embeds MESSAGE text into the
existing sqlite under a `log:` namespace. Same bge-small-en-v1.5 on NPU,
same brute-cosine, same `-r` rerank path. Query returns
`unit  ts  message` ranked lines.

7-day rolling window, hour-bucket dedup (most journal noise is the same
line repeated) — keeps the corpus addition under ~2k chunks so brute-force
cosine stays sub-second.

## why (seed → our angle)

**Seed:** Mic92 `db-cli` queries structured stores literally; nixpkgs
`lnav`/`journalctl -g` are regex-only; loki/grafana do semantic-ish log
search but server-side. Nobody puts a local embed model in front of
journald.

**Our angle:** sem-grep already indexes code + shell-history +
(soon, via live-caption-log's nightly fold) spoken audio. Journald is the
fourth ambient text stream on nv1 and the one we actually grep most during
ops-deploy debugging. The model + index + query path already exist — this
is one verb and one timer.

## falsifies

Whether bge-small (prose/code-trained) embeds **machine log lines**
usefully. Log text is high-symbol, low-grammar, template-repetitive — a
different distribution from everything sem-grep indexes today.

- **If yes** (beats `journalctl -g` on ≥7/10 real queries pulled from
  ops-deploy-nv1.md history — "wake-listen crash", "wifi drop yesterday",
  "openvino conversion error"): MiniLM generalizes further than expected;
  sem-grep becomes the single search surface and the live-caption-log →
  sem-grep nightly fold (already planned, modules/home/desktop/live-caption.nix)
  is validated by proxy.
- **If no**: that's the boundary — code/prose/shell-hist embed fine,
  machine-generated text doesn't. **Kill the live-caption fold too**
  (caption jsonl is closer to log-shaped than prose-shaped) and keep
  sem-grep human-authored-only. Saves a nightly NPU job either way.

## how-much

~0.3r. `log` verb + `index-log` sub in `packages/sem-grep/sem-grep.py`
(~50 LoC: journalctl→json→hour-bucket→embed); systemd user timer in
`modules/home/desktop/sem-grep.nix` next to the existing repo-index timer.
Zero new deps (`journalctl` via systemd, `jq` already in closure, python
json stdlib). 10-query bench in `packages/sem-grep/bench-log.txt`.

## blockers

None for landing. Bench needs a populated journal → gated on
ops-deploy-nv1 (same as every NPU measurement).
