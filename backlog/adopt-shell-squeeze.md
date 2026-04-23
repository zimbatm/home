# adopt: agentshell squeeze shims — terse-by-default for noisy CLIs

## What

`packages/shell-squeeze/`: a handful of `writeShellScriptBin` shims
that shadow the noisiest commands grind subagents actually run, with
terse defaults wired in. Candidates from a `refs/notes/tokens` +
grind-log sweep, but obvious first cut: `git log` → `--oneline -n40`
unless `-p`/`--stat` explicit; `nix eval` → `| head -c4k` cap with a
`[...N more bytes]` tail; `find` → implicit `-maxdepth 4` + `| head
-200`; `tree` → `-L 3`. Each shim falls through to the real binary on
any flag it doesn't recognise (zero behaviour change for deliberate
calls).

Prepend to PATH only inside the grind subagent env (the `agentshell`
profile-link step in the grind setup block) — interactive zsh on nv1
stays untouched.

## Why (seed → our angle)

Seed: **rtk** (rtk-ai/rtk, new in llm-agents.nix since last scout) —
"CLI proxy that reduces LLM token consumption by 60-90% on common dev
commands". It sits as a proxy in front of arbitrary commands and
rewrites/truncates output.

Our angle: we already have the *advice* layer
(`.claude/workflows/tool-hints.md`, 46L of "prefer Read/Grep, cap
with `| head`") and the *measurement* layer (`refs/notes/tokens` per
merge). What we don't have is the *enforcement* layer between them.
rtk does it as a generic proxy; we can do it as a tiny PATH overlay
because agentshell already pins PATH (flake.nix:106) and we know
exactly which ~6 commands dominate grind output. No proxy daemon, no
new inputs — just shims in a buildEnv.

## Falsifies

Shell-layer terseness vs hint-layer discipline: does a PATH overlay
move the `refs/notes/tokens` median, or are subagents already
disciplined enough that the cap never fires? Bench: 5-round grind with
shims on vs 5 prior rounds (same specialist mix), compare
`token-cost.sh table` med_billable per role.

Pass bar: ≥15% drop in any non-META role's median with zero gate
failures attributable to truncation (i.e. no "couldn't see the error
because it was past the cap" — check via gate-fail commit messages).

Decides: agentshell stays a plain passthrough buildEnv (shims are
theatre) vs grows an opinionated wrapper layer (shims are
load-bearing → upstream the pattern to kin's `agentshell`).

## How much

~0.3r. `packages/shell-squeeze/default.nix` is ~5×
`writeShellScriptBin` + one `symlinkJoin`. Wire into the existing
`.#agentshell` output (kin-side change is a follow-up cross-file if
the bench passes; for now `lib.makeBinPath [shell-squeeze] ++` in the
grind setup block PATH line). Bench reuses `token-cost.sh` as-is.
