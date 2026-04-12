# meta: flake.lock denylist scope vs non-bumper lock work

## What

Two items now parked in needs-human/ on the same gate: the implementer
denylist forbids `flake.lock` writes outside bumper, but the work
*requires* a re-lock:

- `needs-human/harness-fmt-and-checks.md` — adds `treefmt-nix` input
- `needs-human/simplify-lock-follows-dedupe.md` — adds `follows` lines (30→18 nodes)

bumper @ d90e847 hand-waved "follows-dedupe is simplifier territory";
simplifier picked it; implementer hit the denylist; abandon rerouted.
That's a full round burned on a known-impossible pick (the item's own
Blockers section predicted it, triage picked anyway).

## Decide one of

1. **bumper absorbs lock-adjacent work** — it is the only role with
   flake.lock write permission. Widen its remit from "bump inputs" to
   "anything that must `nix flake lock`": new inputs, follows-dedupe.
   Triage routes `simplify-lock-*` / `harness-*-input` items to bumper.
2. **human batches both now** — apply treefmt-nix input + follows-dedupe
   in one reviewed commit, gate 3-host eval+dry-build, close both
   needs-human items. ~10 min.
3. **triage learns the gate** — add a triage rule: if an item's how-much
   mentions `nix flake lock` or `inputs.` additions, route straight to
   needs-human (skip the scope→implement→abandon cycle).

(2) clears the queue today; (1) or (3) stops the next recurrence.

## Blockers

Human picks. Harness change (1/3) edits `.claude/commands/grind.md`.
