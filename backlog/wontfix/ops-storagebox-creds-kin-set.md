> **Wontfix (2026-04-10):** storagebox u351392 no longer exists. Config removed; see backlog/ops-gotosocial-backup-target.md for the replacement story.

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

**Escalation (drift-check 2026-04-09 @ ad09bae):** since the kin bump
to ≥0d5df8f (landed via a12d1ce, now at b643e9c), the missing
`gen/user/gotosocial-storagebox-credentials/_shared/credentials.age`
hard-fails eval for **relay1 and web2** — `kin status` and
`nix eval .#nixosConfigurations.{relay1,web2}...toplevel` both error
out. Gate is RED on main for 2/3 hosts; only nv1 evals (drv
`09jlk4zk…`). Until this closes, grind specialists can't pass the
all-hosts-eval gate and drift-checker can't compute desired state for
the two servers.

**Falsifies:** "external generators via `kin set` work end-to-end" — if
the gen schema needs an `external = true` marker that isn't there,
that's a tiny kin fix first.
