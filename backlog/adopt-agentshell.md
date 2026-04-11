# adopt: agentshell SessionStart hook (blocked on kin mkFleet)

## What
- `.claude/settings.json`: add SessionStart hook `nix build .#agentshell --out-link .claude/profile 2>/dev/null || true; [ -n "$CLAUDE_ENV_FILE" ] && printf 'export PATH="%s/.claude/profile/bin:\$PATH"\\n' "$CLAUDE_PROJECT_DIR" >> "$CLAUDE_ENV_FILE"`
- `.gitignore`: `.claude/profile`
- flake.nix: no change — `packages.agentshell` arrives via kin's mkFleet (see `../kin/backlog/adopt-agentshell.md`).

## Why
Agent never depends on host PATH. interfaces.md § operator shell is the contract.

## How much
~10 lines settings.json. The flake side lands when kin's mkFleet emits agentshell.

## Blockers
`../kin/backlog/adopt-agentshell.md` — mkFleet emit. Hook is safe to add now (`|| true` tolerant; activates when output exists).

## Falsifies
After kin bump + SessionStart, `which git` → `.claude/profile/bin/git`.
