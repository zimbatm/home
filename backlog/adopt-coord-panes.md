# adopt: coord-panes — workmux's idea via tmux + harness peer-bus, no daemon

## What

A `packages/coord-panes` helper + `/coord` skill:

- `coord-panes spawn <cwd> [<label>]` → opens a tmux pane in the
  current window running `claude --permission-mode acceptEdits` with
  cwd set, waits (≤10s) for its UDS socket to appear, prints the
  `uds:/...` peer address.
- `coord-panes ls` → tmux pane-id ↔ peer-address ↔ cwd table.
- `coord-panes kill <label|addr>` → close pane.

The `/coord` skill is the recipe: spawn N panes, `SendMessage` each a
scoped task, poll with `ListPeers`/`SendMessage "status?"`, collect.
Reuses `pty-puppet` for the spawn-and-wait-for-socket step.

## Why (seed → our angle)

**Seed:** Mic92 now ships `workmux` (github.com/Mic92/workmux) +
its `coordinator` skill via llm-agents.nix — a tmux-based multi-agent
supervisor with its own queue, lockfiles, and config. Newest thing in
his `ai.nix` since the wontfix.

**Our angle:** don't import the supervisor. nv1's harness *already
has* the IPC layer workmux rebuilds: `Tmux` (pane control),
`ListPeers`/`SendMessage` (peer bus), `pty-puppet` (spawn+expect).
`coord-panes` is the ~40-line glue that makes "spawn a sibling Claude
in the next pane and hand it a task" a one-liner — tmux is the process
supervisor, the peer bus is the queue. grind already proves
worktree-parallelism works for *this repo*; coord-panes generalises it
to ad-hoc cross-repo fan-out ("bump kin, iets, maille in three panes;
tell me when all green") without grind's round structure.

## Falsifies

- **Is workmux's lock/queue layer load-bearing?** Hypothesis: for a
  single-user desktop, tmux + peer-bus is sufficient and workmux's
  config.lock / job-queue is overhead. Run the morning sibling-bump
  chore (4 repos, 4 panes) daily for a week. If we hit the
  git-config.lock race workmux explicitly patches around (see Mic92's
  `fix-config-lock-race` branch ref in his ai.nix), that's the signal:
  adopt workmux proper, drop this.
- **Peer-bus discovery latency**: does `ListPeers` pick up a
  freshly-spawned pane's socket in <10s reliably, or does it need a
  filesystem-watch nudge? If flaky, the harness primitive needs work
  (file upstream), not coord-panes.

## How much

~0.3r. `tmux split-window -c <cwd> -P -F '#{pane_id}'` + a poll loop
on `~/.claude/ide/*.sock` mtime + one SKILL.md. No new deps; tmux and
pty-puppet are already in closure.

## Blockers

None hard. Soft: decide whether spawned panes inherit
`--dangerously-skip-permissions` or `acceptEdits` — the former matches
grind's model, the latter is safer for ad-hoc. Start with
`acceptEdits`.
