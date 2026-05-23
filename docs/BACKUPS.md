# Backups

What gets backed up where, last verified to actually capture data, and what's
deliberately not.

| host | service | repo (rsync.net) | last verified | typical size |
|---|---|---|---|---|
| **chat** | weechat | `…/weechat` | 2026-05-23 | ~few MB |
| **web2** | gotosocial | `…/gotosocial` | 2026-05-23 (21,366 files / 7.57 GiB) | ~7 GiB |
| **mail** | stalwart | `…/mail` | 2026-05-23 (137 files / 5.09 GiB) | ~12 GiB |
| **mc1**  | minecraft worlds | `…/mc1` | 2026-05-23 (2385 files / 911 MiB) | ~1 GiB |

All paths live at `sftp:zh6422@zh6422.rsync.net:zimbatm-home-backup/<repo>/`.
Schedule: daily systemd timer with 30-min randomized delay.

Retention: keep 7 daily, 4 weekly, 6 monthly (per `pruneOpts` in each
`services.restic.backups.<name>`).

## What's deliberately NOT backed up

- **nv1** (local desktop). State is `~/.config/sops/age/keys.txt` (the only
  thing you can't recreate from this repo) and `~/Documents`-style stuff. The
  keys.txt should already be backed up to your YubiKey/paper recovery; the
  rest is replaceable.
- **agents** (cpx62, fsn1). Tmux sessions + scratch claude work. If lost,
  re-bootstrap from this flake; no irreplaceable state.

## The empty-snapshot trap (now fixed everywhere)

All four restic units previously had `CapabilityBoundingSet = ""` in their
systemd hardening, which silently stripped `CAP_DAC_READ_SEARCH`. restic ran
as root but couldn't traverse `0700`/`0750` service-owned data dirs — every
run produced `Files: 0 new, 0 changed` snapshots while reporting "success".

Fixed 2026-05-22/23: `CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" ]` +
`AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" ]` on each
`restic-backups-<service>` unit. Same fix applied to mail, web2, chat, mc1.

**Diagnostic check after future hardening tweaks:**

```bash
ssh root@<host> 'journalctl -u restic-backups-<service> -n 30 --no-pager' \
  | grep -E "Files:|denied"
```

If you see `permission denied` or `Files: 0 new`, the sandbox is wrong.

## Single-point-of-failure: rsync.net

All four hosts back up to the same rsync.net account (`zh6422`). If that
account goes away (billing lapse, account compromise, rsync.net outage), we
lose all offsite backups simultaneously.

Mitigations to consider (none in place yet):
- Second offsite destination (Backblaze B2, Hetzner Storage Box).
- Local restic-snapshot mirror on nv1 via cron pulling from rsync.net.
- Encrypted snapshot export to a cold tarball periodically.

## How to actually restore

See [runbooks/restic-restore.md](runbooks/restic-restore.md).

## Verifying a backup integrity check ran

```bash
ssh root@<host> 'systemctl list-timers restic-backups-* --all'
```

Confirms next-fire times. To force a fresh run:

```bash
ssh root@<host> 'systemctl reset-failed restic-backups-<svc> && systemctl start restic-backups-<svc>'
ssh root@<host> 'journalctl -u restic-backups-<svc> -n 30 --no-pager | grep processed'
```

Look for `processed <N> files, <SIZE>` — the success signal.
