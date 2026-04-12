# meta: skip-predicate for drift/simplifier on zero .nix-delta (config-only re-scope)

**What:** Prepend an early-exit guard to the **drift** and **simplifier**
specialist prompts in `.claude/grind.config.js`: first action is
`git log -1 --format=%H --grep='^<role> @' origin/main` →
`git diff --name-only <sha>..origin/main -- '*.nix' kin.nix gen/`.
If empty, the specialist writes a one-line skip commit
(`<role> @ <sha>: skip — zero .nix-delta since <last>`) and returns
immediately. No harness change.

**Why:** DRIFT-CHECKER DRY 3× consecutive (r9/r10/r12 — 127k med tok,
0 filed); simplifier flagged same @ 3961905. Both inspect .nix state;
re-running against an unchanged tree is pure re-read. First attempt
(2f9e85d, r12) put the skip in `forceSpecialist` but needed a
`.claude/workflows/grind-base.js` signature change → denylist abandon.
Prompt-level guard achieves ~95% of the savings (specialist still spawns
but exits in ~5-10k tok vs 127k) with zero harness touch.

**How much:** ~6 lines prepended to each of `specialists.drift` and
`specialists.simplifier` template strings in grind.config.js. Gate:
fastCheck unaffected; verify by grepping the rendered prompt.

**Blockers:** none — grind.config.js is grind-editable (precedent:
harness-fastcheck 2b42336). bumper/scout untouched.
