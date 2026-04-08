---
description: Dogfood grind — drift-check, simplify, bump inputs; gate = all hosts eval+build
---

The home fleet grind. Implementers consume `backlog/`; rotating specialist
(drift / simplifier / bumper) refills it. Gate: every host evals + dry-builds.

**Deploy is NOT automatic.** Merged changes are committed, not applied.
Meta phase reminds you to `kin deploy` if hosts/ or kin.nix changed.

## Stopping

`touch .grind-stop` — finishes current round then exits.

## Launch

1. Check no grind running: `ls ../home-grind/_base/.git 2>/dev/null`
2. `rm -f .grind-stop`
3. Read `.claude/workflows/home-grind.js` and `.claude/workflows/grind-base.js`
4. `Workflow({script: project + "\n" + base, args: ${ARGUMENTS:-{}}})`

Args: `/grind` (infinite, 2 implementers) · `/grind {rounds:1}`
