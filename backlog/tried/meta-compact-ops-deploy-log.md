# tried: meta-compact-ops-deploy-log

## Outcome
- r8 impl: abandoned pre-merge (denylist hit on `.claude/workflows/grind-base.js`).
- r8 META: **primary fix applied directly** — ops-deploy-nv1.md compacted
  424L→128L in place (option 1: cumulative bisect table + latest status
  + cumulative runtime checks + append-log marker). All per-commit
  attributions preserved. Item closed.

## Why impl abandoned
Branch reached for the **secondary** harness suggestion (META re-read
shape) which touches `.claude/workflows/grind-base.js` — denylisted
(grind cannot modify its own orchestration mid-round). The **primary**
fix (compact the backlog file itself) does not touch workflows and was
grind-safe; impl mis-scoped.

## Secondary (harness) — not needed
META already reads needs-human bodies via `head -8` per file, not full
Read; the cost driver was the bisect-attribution payload Jonas needs,
which is now table-form. If unbounded growth recurs the append-log
marker tells META when to re-compact (>3 entries).

## Re-attempt when
n/a — done. If a future filing again bundles a workflows/ edit with a
backlog edit, scope-splitter should peel the workflows/ part to
needs-human and keep the rest actionable.
