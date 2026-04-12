# adopt: sem-grep — NPU-resident embedding index over the assise repos

## What

`packages/sem-grep`: a tiny embedding model (bge-small-en or all-MiniLM,
~33M params, ONNX) resident on the Meteor Lake NPU, indexing git-tracked
text in `~/src/{home,kin,iets,maille,meta}` into a flat sqlite+blob
store under `$XDG_STATE_HOME/sem-grep/`. Query side:

    sem-grep "where do we set the worker ssh CA"
    → ranked file:line hits by cosine sim, capped at N

Reuses `transcribe-npu`'s OpenVINO env (no new python closure). Index
refresh hooks on `git post-commit` per repo or runs as a low-priority
`infer-queue` lane — incremental, only re-embeds changed files.

## Why (seed → our angle)

**Seed:** Mic92 ships `context7-cli` (cloud docs lookup) and `kagi-search`
(paid web search) as agent skills; sourcegraph/amp do semantic code
search via cloud index. All three answer "where is X" with a network
round-trip.

**Our angle:** the question agents on nv1 actually ask is "where in
*these five repos* is X configured" — a closed corpus, ~2k files. That
fits in a local index. Put the embed model on the NPU (proven by
wake-listen's Silero residency) so Arc stays free for ask-local, and
the index refresh is ambient like VAD. Zero cloud, zero paid API, and
the corpus is exactly the assise dogfood — so hit quality is itself a
dogfood signal.

## Falsifies

- **NPU co-residency**: can the NPU host bge-small *alongside* Silero
  VAD without wake-listen latency regressing? Measure via `agent-meter`
  npu_busy% + wake-listen's own gate-latency log. If contention,
  the NPU-as-ambient-coprocessor thesis caps at one model.
- **Embed-vs-ripgrep**: for 20 real "where is X" queries pulled from
  recent grind rounds, does sem-grep top-5 beat `rg -l` on recall?
  Log to `$XDG_STATE_HOME/sem-grep/evals.jsonl`. If ripgrep wins,
  semantic search over small structured corpora is theatre.

## How much

~0.5r. writeShellApplication + one python script (stdlib + openvino +
numpy, all already in transcribe-npu's closure). sqlite for the
chunk→vec store (no faiss; corpus is small enough for brute-force
cosine). SKILL.md so agents reach for it before Grep on fuzzy queries.

## Blockers

None for pkg+index. Query-latency measurement and co-residency test
gated on `ops-deploy-nv1` (NPU only enumerates on real hw).
