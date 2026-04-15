# adopt: rerank-pass — cross-encoder stage-2 for sem-grep, 3rd NPU tenant

## What

`sem-grep -r "<q>"`: retrieve top-30 by the existing bge-small cosine,
then rerank to top-5 with a cross-encoder (bge-reranker-base, OpenVINO
IR ~280 MB fp16, `OpenVINO/bge-reranker-base-fp16-ov` on HF) compiled
to `NPU`. Same python (`openvino+transformers+numpy`), same XDG model
dir, same fetch-hint-on-miss pattern as sem-grep already uses. Plain
`sem-grep` stays bi-encoder-only; `-r` is opt-in.

## Why (seed → our angle)

**Seed:** retrieve-then-rerank is table stakes in every RAG stack —
context7-cli, kagi-search (Mic92 mics-skills), llamaindex, the lot.
sem-grep is bi-encoder brute-cosine only; top-10 is noisy on short
queries because bge-small can't see query/passage interaction.

**Our angle:** the reranker becomes the **third concurrent NPU
tenant** alongside Silero VAD (wake-listen) and bge-small embed
(sem-grep). Nobody publishes Meteor-Lake NPU multi-model co-residency
numbers; we already have two residents and agent-meter to watch them.
The reranker is the natural next probe — bigger than both (~110 M
params vs 33 M / 1 M), exercises the scheduler harder.

## Falsifies

1. **NPU 3-model ceiling** — does `core.compile_model(reranker,"NPU")`
   succeed with VAD+embed already loaded, or OOM/evict? Observe via
   agent-meter npu-busy% + `dmesg | grep ivpu` during a wake-listen +
   `sem-grep -r` overlap. If it evicts: the 2-tenant assumption baked
   into infer-queue's `npu` lane is the actual cap.
2. **Rerank > cosine on our corpus** — rerun the 20-query grind
   benchmark from adopt-sem-grep; does cross-encoder top-5 beat
   cosine top-5 hit-rate by enough to justify the ~200 ms/query cost?
   If not on a 2 k-file corpus, rerank is cargo-cult here.

## How much

~0.3r. Extends `packages/sem-grep/default.nix` python body (one extra
model load + a `rerank(query, passages)` scoring loop). No new nix
deps, no flake.lock touch. Model fetch is XDG runtime, not FOD (matches
bge-small precedent).

## Blockers

None. Gated on ops-deploy-nv1 only for the falsification measurements;
the code lands and dry-builds without it.
