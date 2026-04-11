# adopt: Mic92 agent-ergonomics tools (zat, mics-skills pattern)

## What

Cherry-pick from [Mic92/dotfiles `ai.nix`]:
- `zat` — signature-outline skill (shows function/type signatures
  instead of full file reads; cuts Read-tool token spend)
- The `mics-skills` HM-module pattern: package local CLIs (browser,
  calendar, screenshot) as Claude skills via a home-manager module

Both reportedly ship via `llm-agents.nix` already — verify and enable.

## Why

Mic92's setup is agent-ergonomics, not voice — but that's the
"future of LLMs" axis nv1 is already on (claude-code, codex, etc.).
`zat` directly reduces context spend for code-reading agents.

## How much

~0.3r if already in `llm-agents.nix` (just enable); ~0.5r if
packaging needed.

## Blockers

Verify `llm-agents.nix` actually exports these (check
`inputs.llm-agents.packages.*` and `homeModules.*`).

[Mic92/dotfiles `ai.nix`]: https://github.com/Mic92/dotfiles/blob/main/home-manager/modules/ai.nix
