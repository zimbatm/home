# adopt: sem-grep `refs` verb — structural xref alongside embed+sig

## What

Add a third query mode to `sem-grep`: `sem-grep refs <symbol>` — who
references this name. Tree-sitter queries (identifier captures per
language) over the same tracked-file walk as `cmd_index`, written to a
new `refs(symbol, repo, path, line)` table in the existing
`index.db`. Index-time only; query is a sqlite lookup, no embed.

Expose in `ask-local --agent` as a `refs` tool alongside the existing
`sem-grep` / `sem-grep-sig` entries in `tools.json`.

Compose: `sig` ⋈ `refs` answers "callers of things shaped like X" —
neither pure-embed (`query`) nor pure-shape (`sig`) gets there alone.

## Why (seed → our angle)

Seed: **gitnexus** ("graph-powered code intelligence for AI agents",
new in llm-agents.nix since last scout) and the LSP/scip family all
build a reference graph, but as a separate server/daemon with its own
index. Mic92 ships nothing for this — `zat` stops at signatures.

Our angle: we already have tree-sitter wired (`_ts_lang`, `sigs_of` at
sem-grep.py:152,163) and the sqlite db. A `refs` table is the missing
structural leg of the tripod (body-embed / sig-embed / name-xref) and
costs zero new inputs. The interesting bit isn't xref itself — it's
whether ts-query xref is *good enough* for a 3.8B agent loop without
dragging in a real language server per language.

## Falsifies

Tree-sitter-identifier-capture xref precision on polyglot Nix+Py+Rust
repos vs hand-checked ground truth. Bench: 20 known-reference cases
across the assise sibling repos (mix of unique names, shadowed names,
same-name-different-lang). Pass bar: ≥16/20 with ≤2 false-positive
files per query.

Decides: does `ask-local --agent` get a `refs` tool (cheap, ship it),
or do we need per-language LSP indexers behind `infer-queue` (file the
heavier item). Also decides whether `sig ⋈ refs` join is worth a
combined verb.

## How much

~0.3r. `sigs_of` already walks the tree-sitter parse; `refs_of` is the
same walk with an identifier-capture query instead of a declaration
query. New `cmd_refs` mirrors `cmd_sig` (sqlite SELECT, no model
load). +1 entry in `packages/ask-local/tools.json`. Bench file
`packages/sem-grep/bench-refs.txt` in the `bench-log.txt` shape.

## Blockers

None — tree-sitter + grammars already in closure via sig-index
(92d2cd8). No flake.lock change.
