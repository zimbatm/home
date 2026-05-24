# Runbooks

Copy-paste-ready procedures for things we've actually executed. If a runbook
here disagrees with reality, fix the runbook — the docs are the source of
truth for "how this was last done."

| | what |
|---|---|
| [provision-new-hetzner-host.md](provision-new-hetzner-host.md) | New cpx/ccx VM, UEFI quirk, nixos-anywhere with SK YubiKey |
| [migrate-volume-between-hosts.md](migrate-volume-between-hosts.md) | Move a Hetzner Cloud Volume from one host to another |
| [dns.md](dns.md) | `nix run .#dns-preview` / `.#dns-push` via dnscontrol |
| [restic-restore.md](restic-restore.md) | Restore from rsync.net backups |
| [stalwart-admin.md](stalwart-admin.md) | Create domains/principals via Stalwart admin API |
| [term-web.md](term-web.md) | Web terminal at agents.ztm.io (mTLS, ttyd, client-cert provisioning) |

Common dependencies these procedures assume:

- `.envrc.local` with `HCLOUD_TOKEN`, `NAMECHEAP_API_USER`, `NAMECHEAP_API_KEY`
- The `zimbatm@p1` YubiKey for SSH; askpass at `gcr4-ssh-askpass` (already in nv1's env)
- agenix key at `~/.config/sops/age/keys.txt`
