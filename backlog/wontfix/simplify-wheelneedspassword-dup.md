# lift `security.sudo.wheelNeedsPassword = false` from web2+relay1

## What

Both server hosts set the same line:

- `machines/web2/configuration.nix` — `security.sudo.wheelNeedsPassword = false;`
- `machines/relay1/configuration.nix` — `security.sudo.wheelNeedsPassword = false;`

nv1 (desktop) does *not* — it uses PAM u2f for sudo instead.

## Why wontfix

No clean lift target that nets fewer LoC:

- **common.nix** — nv1 imports it via `desktop.nix`; would change nv1's sudo
  posture (passwordless sudo on a laptop with u2f already wired is a downgrade).
- **new `modules/nixos/server.nix`** — relay1 is intentionally minimal and
  imports nothing from `inputs.self` today. Adding a module file + two
  `imports` lines to dedupe one option line is net +LoC.
- **kin `hetzner-cloud` profile** — both servers use it, but pushing a
  personal sudo policy into kin's generic cloud profile is wrong layering.

2 lines of duplication < any abstraction to remove them. Revisit only if a
third server appears *and* it shares more than this one line with web2/relay1.

## History

Noted-and-skipped in three prior simplifier rounds (33d4860, 0ca1cc8,
6ad176d) via commit message only — filing here so the next sweep greps
`wontfix/` instead of re-deriving.
