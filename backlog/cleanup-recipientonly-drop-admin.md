# cleanup: drop redundant admin=true on recipientOnly user

## what

`kin.nix:21-24` sets `users.zimbatm-yk = { admin = true; recipientOnly =
true; }`. As of kin `spec/model.nix` schema-honest fix (grind/schema-
recipientonly-admin-redundant-2of2), `recipientOnly = true` mkDefaults
`admin = true`, so the explicit `admin = true` is now the documented
no-op it always semantically was (lib/fleet-ctx.nix adminKeys folds
`u.admin || u.recipientOnly`).

## why

Match the spec/model.nix "complete spelling" comment: `{ recipientOnly =
true; }` alone. 1L cleanup; no behaviour change.

## how-much

Drop the `admin = true;` line from `users.zimbatm-yk`. Works on any kin
pin (OR-fold predates the schema fix). No flake.lock bump required.

## blockers

None.

## falsifies

`kin gen --check` clean; `nix eval .#kinManifest.admins` still contains
keys/users/zimbatm-yk.pub.
