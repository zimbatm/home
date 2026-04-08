# Provide storagebox creds via `kin set`

**What:** Run `kin set gotosocial-storagebox-credentials` with the
Hetzner storagebox CIFS creds so `gen/` materializes and the
`/mnt/gotosocial-backup` mount (`modules/nixos/gotosocial.nix:29-33`)
works on the deployed host.

**Why:** Generator declared (`kin.nix:33`), consumer wired
(`gotosocial.nix:33`); the secret value was just never provided. Last
non-relay item in assise next.md A2-remaining.

**How much:** One command + `kin gen` + `kin deploy web2`. Verify
`systemctl status mnt-gotosocial\\x2dbackup.mount` is active and
`restic snapshots` lists one.

**Blockers:** none. Human-in-the-loop (needs the actual Hetzner creds).

**Falsifies:** "external generators via `kin set` work end-to-end" — if
the gen schema needs an `external = true` marker that isn't there,
that's a tiny kin fix first.
