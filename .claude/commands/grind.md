---
description: Dogfood grind — drift-check, simplify, bump inputs; gate = all hosts eval+build
---

The home fleet grind. Implementers consume `backlog/`; rotating specialist
(drift / simplifier / bumper) refills it. Gate: every host evals + dry-builds.

**Deploy is NOT automatic.** Merged changes are committed, not applied.
Meta phase reminds you to `kin deploy` if machines/ or kin.nix changed.

## Stopping

`touch .grind-stop` — finishes current round then exits.

## Launch

1. Check `ls ../home-grind/_base/.git 2>/dev/null` — if it exists, that may be stale from a killed session (the workflow will sync it). Only STOP if you see another /grind Workflow task actively running for this repo.
2. `rm -f .grind-stop`
3. `NS=$(nix build --no-link --print-out-paths .#nix-skills-commands 2>/dev/null) && ln -sf "$NS"/share/nix-skills/nix-{module,deploy,debug,hardware,secret}.md .claude/commands/ 2>/dev/null` — refresh nix-skills (best-effort)
4. Read `.claude/grind.config.js` and `.claude/workflows/grind-base.js`
5. `Workflow({script: project + "\n" + base, args: ${ARGUMENTS:-{}}})`

Args: `/grind` (infinite, 2 implementers) · `/grind {rounds:1}`
