# meta: compact ops-deploy-nv1.md (424L / >10k tok, Read tool errors)

**What:** `backlog/needs-human/ops-deploy-nv1.md` is 424 lines and now
exceeds the 10k-token Read limit — meta r7 hit `File content (10023
tokens) exceeds maximum`. 9 appended `## drift @ <rev>` sections since
the original filing, each repeating the same boilerplate (kin status
json block, "have carried forward", "Reconcile: kin deploy nv1", "same
nixpkgs 4c1018d throughout").

**Why it matters:** META token-cost crept 1.2×→1.5× impl_med across
r6→r7; the needs-human re-read of this file is the dominant driver.
Unbounded — drift appends every round nv1 stays undeployed, and
ops-kin-login-worker (hardware-key-gated) means that's open-ended.
ops-deploy-relay1-web2.md is on the same trajectory (143L, 5 sections).

**Proposed fix (pick one, ~0.2r):**

1. **Compact in place** — collapse the 9 drift sections into a single
   cumulative per-commit attribution table (commit → host(s) affected →
   want-hash delta) + the LATEST `kin status` block + reconcile steps.
   Preserves every bisect result; drops repeated prose. Drift keeps
   appending; meta re-compacts when sections >3.

2. **Split** — move the append-log to
   `backlog/needs-human/ops-deploy-nv1.log.md`, keep the runbook
   (header + cumulative table + checks) in the main file. Drift appends
   to `.log.md`; human reads the runbook.

**Secondary (harness):** meta's "re-read needs-human bodies" is for
testable gating assumptions ("needs token X" → try it). ops-deploy-*
gating is **policy** (CLAUDE.md: "Never run kin deploy"), not
assumption — body re-read yields nothing actionable. Meta should
`wc -l` + `grep '^## drift @'` these instead of full Read. Saves ~10k
tok/round once compacted, ~unbounded if not.

**Blockers:** none. Don't lose per-commit bisect attributions — Jonas
needs them to spot-check before `kin deploy nv1`.
