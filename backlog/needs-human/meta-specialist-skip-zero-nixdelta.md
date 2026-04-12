# meta: skip specialist rotation on zero .nix-delta

**What:** Add a rotation-skip predicate to triage: when the next
specialist in rotation is **drift** or **simplifier** and
`git diff <last-same-role-commit>..HEAD -- '*.nix' kin.nix gen/` is
empty, skip that slot and advance rotation.

**Why:** DRIFT-CHECKER flagged DRY two consecutive rounds (r9 c2c706a,
r10 — 3 runs / 0 filed, ~127k med tokens). Root cause is structural,
not a bad role: probe-blind on ops-worker-ssh-reauth + no deploy since
e196255 means drift can only re-confirm the same gap. b103483's one
useful act (correct stale want= hash) only mattered because .nix *had*
moved; with 0 .nix-delta there is nothing to re-eval. Simplifier noted
the same @ 3961905 ("second consecutive clean sweep — could skip next
round if no .nix commits land"). Both roles inspect .nix state; running
them against an unchanged tree is pure re-read.

**How much:** ~10 lines in `.claude/grind.config.js` rotation picker:
```js
const lastRoleSha = git('log -1 --format=%H --grep="^<role> @"');
const nixDelta = git(`diff --name-only ${lastRoleSha}..HEAD -- '*.nix' kin.nix gen/`);
if (!nixDelta && (role === 'drift' || role === 'simplifier')) advance();
```
Gate: existing fastCheck unaffected (rotation-only change).

**Blockers:** none. Doesn't retire either role — they fire the moment
.nix moves. bumper/scout stay every-round (they *create* .nix-delta).
