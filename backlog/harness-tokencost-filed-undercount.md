# harness: token-cost.sh undercounts direct-commit specialists' filed/run

**What:** `.claude/workflows/token-cost.sh --by-role` reports SCOUT
filed=0/run despite scout having filed ≥8 backlog/adopt-*.md items over
3 runs (4c1bd76, e473c5a, e8b3d94 etc). Same for BUMPER and
DRIFT-CHECKER — all direct-commit roles show 0 filed.

**Why:** The DRY flag (≥3 runs, <0.5 filed/run) is meant to catch
specialists that produce nothing. False DRY on scout/bumper/drift risks
a future meta wrongly filing meta-retire-<role>.md. Noted in r12 + r13
meta as "reporting nit" — file so it stops getting re-noted.

**Guess at cause:** script likely counts `backlog/*.md` adds only on
merge commits or only on commits whose role-tag matches a merge, missing
specialists that `git commit` directly to main. Check the
filed-detection grep/awk in token-cost.sh.

**How much:** ~10-20L shell. Read token-cost.sh, find where `filed` is
derived, widen to include direct commits authored under the role's run
window (or match commit-message role prefix).

**Done when:** `--by-role` shows SCOUT filed ≥2.0/run (8+ items / 3
runs) and DRIFT-CHECKER reflects its needs-human/ updates.
