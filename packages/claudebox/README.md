# claudebox - responsible YOLO

Run Claude Code in YOLO mode with transparency.

See all commands Claude executes in a tmux split pane.

## Usage

```bash
claudebox
```

Opens Claude Code with:
- Left pane: Claude interface
- Right pane: Live command log

## What it does

- Lightweight sandbox using bubblewrap
- Intercepts all commands via Node.js instrumentation
- Shows commands in real-time in tmux
- Disables telemetry and auto-updates
- Uses `--dangerously-skip-permissions` (safe in sandbox)

## Note

Not a security boundary - designed for transparency, not isolation.

## Future ideas

- direnv reload integration
- git worktree support
