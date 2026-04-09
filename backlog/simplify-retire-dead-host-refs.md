# retire dead-host refs: no1/p1/silent1/x1

## What

`hosts/` has exactly nv1, relay1, web2. But pre-kin-migration host names
linger in three places that grep can see and `kin gen --check` can't:

- `README.md:13` — "`no1` and `p1` have host configs but aren't
  kin-managed yet." False: no `hosts/no1/`, no `hosts/p1/`. Delete the
  line.
- `.github/settings.yml:68-71` — branch-protection
  `required_status_checks.contexts` lists `nixosConfig no1`,
  `nixosConfig silent1`, `nixosConfig x1`. None of these
  nixosConfigurations exist; the probot-settings sync would make every
  PR unmergeable. Replace with the three real hosts (or drop the
  contexts list — CI shape moved to kin gate anyway).
- `keys/machines/no1.pub`, `keys/machines/p1.pub` — age recipients for
  machines not in `kin.nix .machines`. `kin gen` walks declared
  machines only, so these are inert, but they leak into
  `gen/_fleet/_shared` recipient sets if kin ever globs `keys/machines/*.pub`.

(`zimbatm@p1` in kin.nix:4 is an SSH-key *comment*, not a host ref —
leave it.)

## Why

Keeps the "3 hosts, ~1200 LoC" invariant honest. The settings.yml one is
a latent foot-gun: next time someone re-enables the probot-settings app,
main locks.

## How much

−1 README line, −2 .pub files, settings.yml contexts 3→3 (swap names) or
3→0. Net ~−5 LoC, zero eval surface. Gate: nv1 dry-build only (the
pre-existing relay1/web2 storagebox RED is orthogonal).

## Blockers

None for README + keys/. The `.github/settings.yml` edit is policy
(branch protection) — flag for Jonas to eyeball before the probot sync
fires, but the change itself is text-only and safe to land.
