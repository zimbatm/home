# ops: rotate identity for `kin://` → `assise://` scheme rename

The identity URI scheme is renamed `kin://` → `assise://`. Every cert
in `gen/identity/**` carries the old scheme in its SAN/ID.

## Do

Same sequence as `../kin-infra/backlog/ops-rotate-assise-uri.md`:
bump kin → `kin gen --rotate identity` → bump maille → `kin deploy
@all` atomically.

## Note

home just did a full `--rotate all` for the leaked-key incident
(home@73b86c7). This is a *second* rotation, but lighter: `--rotate
identity` keeps the CA key (via `$prev`) so fleet-id, ULA prefix, and
mesh fingerprints are unchanged — only the SAN/ID strings inside
certs change. No federation peer needs re-exchanging.

## Sequence

1. `nix flake update kin` (past the rename SHA)
2. `nix develop -c kin gen --rotate identity`
3. `kin gen --check` exit 0; verify `gen/_fleet/_shared/fleet-id`
   unchanged
4. Bump maille (via kin's lock or `nix flake update maille`)
5. `kin deploy @all` — all 3 machines in one round
6. `ssh nv1 cat /etc/kin/identity/id` → `assise://…`; mesh healthy

## Blockers

- needs-human: yubikey (zimbatm-yk). Can batch with
  `adopt-attest-second-builder.md` enable.

## Falsifies

If new maille on relay1 with new certs can't reach nv1 still on old
certs mid-deploy, the "deploy @all atomically" assumption is wrong
and a two-phase (regen+deploy-kin-only, then bump-maille+redeploy) is
needed instead.
