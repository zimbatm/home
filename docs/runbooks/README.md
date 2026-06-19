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
| [term-web.md](term-web.md) | Web terminal at agents.ztm.io (ttyd behind Pocket ID SSO) |
| [ssh-tpm-agent.md](ssh-tpm-agent.md) | Migrate SSH-from-nv1 to TPM-backed (silent, no SSH_ASKPASS dance) |
| [tinc-ztm.md](tinc-ztm.md) | Stand up the tincr `ztm` mesh between all 6 hosts (10.42.0.0/24) |
| [bluesky-pds.md](bluesky-pds.md) | Self-hosted AT Protocol PDS at pds.zimbatm.com; account migration |

Common dependencies these procedures assume:

- `.envrc.local` with `HCLOUD_TOKEN`, `NAMECHEAP_API_USER`, `NAMECHEAP_API_KEY`
- The `zimbatm@p1` YubiKey for SSH; askpass at `gcr4-ssh-askpass` (already in nv1's env)
- agenix key at `~/.config/sops/age/keys.txt`
