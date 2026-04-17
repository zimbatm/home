# adopt: sem-grep `sig` verb — treesitter signature index (our zat)

## seed

Mic92 ships `zat` (llm-agents.nix): treesitter outline viewer that prints
exported signatures + line numbers so an agent can `Read(offset,limit)`
instead of slurping whole files. wontfix/adopt-mic92-agent-tools.md
(2026-04-11) rejected importing it verbatim but explicitly left the
signature-outline idea open: "file fresh adopt-* items if/when we design
our own take." Prior scouts (4ad6529, d39fb6d) skipped zat as
verbatim-copy each round without filing the angle. This is the angle.

## our angle

zat is a *viewer* — it answers "outline this file I already found." We
already have the finder: sem-grep's NPU bge-small index over the assise
repos. Fuse them the other way round: extract signatures with treesitter
*at index time* and embed those instead of (in addition to) body chunks.

`sem-grep sig "<query>"` → ranked `file:line  signature` hits from a
`sigs` sqlite table (same DB, same bge-small model, same NPU). Indexer
walks `pkgs.tree-sitter.withPlugins` (nix/python/bash/rust grammars —
covers ~all of home/kin/iets/maille) and emits one row per top-level
def: name, params, return/type annotation, docstring first-line.

Why this isn't just "smaller chunks": signatures are interface-shaped
text. "thing that takes a fleet name and returns a derivation" should
rank the right `mkHost` even when the body never says "fleet" — the
param name does. Full-chunk embed conflates topic-match with
shape-match; a sig table separates them.

## how much

~0.3r. `pkgs.tree-sitter` 0.25.10 + `tree-sitter-grammars.tree-sitter-{nix,
python,bash,rust}` already in nixpkgs — **zero new flake inputs**. Reuse
sem-grep.py's embed/store/cosine path verbatim; new code is the
treesitter walk (one query per grammar, ~40 lines) + the `sig` verb
dispatch. Corpus shrinks ~10× vs body chunks → reindex stays sub-second.

## falsifies

- **bge-small on type-signature text**: the model was trained on
  prose+code-body. Signature lines are a different distribution (dense,
  no narrative). Run the existing 20q grind bench against `sig` vs
  body-chunk; if sig recall ≥ body on the "where is the function that…"
  subset, sem-grep default flips to sig-first-then-body-fallback. If it
  tanks, bge-small can't do interface-shape and we need a code-specific
  embed (decides whether to look at jina-code/unixcoder next).
- **agent Read-spend**: wire `sem-grep sig` into ask-local's tools.json
  alongside plain `sem-grep`; re-run bench-agent.jsonl. If the 3.8B
  picks `sig` for code-nav prompts and token spend drops, that's the zat
  win without the zat dep.

## blockers

None. Measurement gated on ops-deploy-nv1 (same as every sem-grep bench).
