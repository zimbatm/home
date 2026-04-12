# tried: harness-tokencost-filed-undercount

**Outcome:** abandoned — scope violation (denylist hit)

**What happened:** grind worktree implementation (branch
`grind/harness-tokencost-filed-undercount`, was 92bbcd3) touched
`.claude/workflows/token-cost.sh`. That file is on the grind denylist:
the harness is not permitted to modify its own metering/orchestration
scripts from inside a round. The backlog item's "How much" explicitly
targets the filed-detection logic in token-cost.sh, so the task as
written cannot be executed by /grind itself.

**File that tripped it:** `.claude/workflows/token-cost.sh`

**Resolution:** worktree force-removed, branch deleted (commits 7f02262 +
92bbcd3 discarded). Original item restored from origin/main and rerouted
to `backlog/needs-human/harness-tokencost-filed-undercount.md`.

**Why needs-human:** triage skips subdirs, so it won't be auto-picked
again. A human reviews and either:
- applies the denylisted change directly (edits token-cost.sh
  out-of-band so `--by-role` counts direct-commit specialists' filed
  work), then deletes the needs-human file; or
- re-scopes the item to avoid token-cost.sh (e.g. separate reporting
  script outside `.claude/workflows/`, or accept the undercount and
  document it in meta-round notes) and moves it back to `backlog/`; or
- deletes it.

**Don't retry as-is:** any fix to the filed-count derivation lives in
token-cost.sh and will hit the same denylist. Re-scope or apply
out-of-band.
