---
name: coord
description: Fan a task out to N sibling Claude sessions in adjacent tmux panes, hand each a scoped piece via the peer bus, collect results. Use for ad-hoc cross-repo parallelism ("bump kin/iets/maille, tell me when all green") that doesn't fit grind's round structure.
---

tmux is the process supervisor; `ListPeers`/`SendMessage` is the queue.
`coord-panes` is the glue that turns "spawn a sibling and hand it work"
into a one-liner.

```sh
coord-panes spawn <cwd> [<label>]   # → "uds:/path/to.sock %42"
coord-panes ls                      # label  pane_id  uds-addr  cwd
coord-panes kill <label|addr|pane>
```

**Recipe:**

1. One `coord-panes spawn <repo> <label>` per target; capture each
   `uds:` address.
2. `SendMessage({to: addr, message: <scoped task>})` — keep tasks
   self-contained (the sibling has no context from this conversation).
3. Poll: `ListPeers` to confirm liveness, `SendMessage "status?"` to
   each for a one-line progress reply. Don't block — interleave with
   your own work.
4. Collect results, then `coord-panes kill <label>` for each.

Spawned panes run `claude --permission-mode acceptEdits` (not
`--dangerously-skip-permissions`) — safer for ad-hoc; matches the
backlog item's soft-blocker resolution.

**Falsification hook:** if the morning 4-pane sibling-bump hits the
git `config.lock` race workmux patches around, that's the signal —
drop this, adopt workmux proper. If `ListPeers` doesn't see a fresh
pane's socket within 10s, the harness primitive needs work: file
upstream, not here.
