---
name: sem-grep
description: Semantic grep over the five assise repos (~/src/{home,kin,iets,maille,meta}) via a local embedding index on the NPU. Reach for this BEFORE Grep when the query is fuzzy or conceptual ("where do we set the worker ssh CA", "what handles wake-word debounce") and you don't have the exact literal.
---

`sem-grep "<natural-language query>"` prints ranked `score  path:line`
hits (top 10) by cosine similarity against a chunked index of every
git-tracked text file in the five repos. No network, no paid API —
bge-small-en on the Meteor Lake NPU, brute-force over sqlite blobs.

```sh
sem-grep "where is the agentshell devshell wired"
sem-grep -n 20 "openvino model directory layout"
sem-grep index    # refresh; incremental on git blob-sha — run after pulls
```

Use it when you'd otherwise Grep for a *concept* without knowing the
token. For a known literal (`rg 'wheelNeedsPassword'`) ripgrep is still
faster and exact — sem-grep is for the "I know it's in here somewhere"
case across all five repos at once. If top hits look wrong the index may
be stale; run `sem-grep index`.

State lives at `$XDG_STATE_HOME/sem-grep/`: `index.db` is the chunk→vec
store, `evals.jsonl` logs every query so the embed-vs-ripgrep recall
test has real traffic to score. `SEM_GREP_DEVICE=CPU` to bypass the NPU.
