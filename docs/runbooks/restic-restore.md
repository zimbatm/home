# restic restore from rsync.net

Backups land at `sftp:zh6422@zh6422.rsync.net:zimbatm-home-backup/<service>/`.
Each host writes its own repo; passwords + SSH key are agenix.

## Prerequisites

- SSH access to the host whose repo you want to restore from (or anywhere
  that has the same agenix secrets decryptable).
- The repo password and rsync.net SSH key, both in agenix.

## List snapshots

On the host that owns the repo (e.g. mail for `stalwart`):

```bash
sudo -i
RESTIC_REPOSITORY=sftp:zh6422@zh6422.rsync.net:zimbatm-home-backup/stalwart
RESTIC_PASSWORD_FILE=/run/agenix/mail-restic-password
SSH_KEY=/run/agenix/mail-restic-ssh-key
restic -o "sftp.command=ssh -i $SSH_KEY zh6422@zh6422.rsync.net -s sftp" \
  -r $RESTIC_REPOSITORY snapshots
```

## Restore to a sandbox dir

```bash
restic -o "sftp.command=ssh -i $SSH_KEY zh6422@zh6422.rsync.net -s sftp" \
  -r $RESTIC_REPOSITORY restore <snapshot-id> --target /tmp/restore-test
```

Pick a recent snapshot ID from `snapshots`. Restore lands at
`/tmp/restore-test/var/lib/<service>/...`.

## Verify integrity

```bash
restic -o "sftp.command=ssh -i $SSH_KEY zh6422@zh6422.rsync.net -s sftp" \
  -r $RESTIC_REPOSITORY check --read-data-subset=5%
```

`--read-data-subset` samples 5% of the repo data to balance speed vs.
coverage. Drop the flag for a full check on small repos.

## Restore over a live service (mail server crashed, etc.)

1. Stop the service: `systemctl stop stalwart`.
2. Move the broken data aside: `mv /var/lib/stalwart /var/lib/stalwart.broken`.
3. Restore from snapshot:
   ```bash
   restic … restore <id> --target /
   ```
   (restic preserves the original path, so this lands back at `/var/lib/stalwart`).
4. Verify perms (esp. ownership): `chown -R stalwart:stalwart /var/lib/stalwart`.
5. Start: `systemctl start stalwart`.
6. Once confirmed healthy, `rm -rf /var/lib/stalwart.broken`.

## The empty-snapshot trap

If you see `Files: 0 new, 0 changed, 0 unmodified` in the systemd journal
for a backup unit despite the service generating data, the sandbox is
blocking the read. The fix is `CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" ]`
plus `AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" ]` on the
`restic-backups-<service>` unit — see machines/mail/configuration.nix.

## Repos in play

| host | repo path | password agenix | ssh key agenix |
|---|---|---|---|
| chat | `…/chat-state` | `chat-restic-password` | `chat-restic-ssh-key` |
| web2 | `…/gotosocial` | `web2-restic-password` | `web2-restic-ssh-key` |
| mail | `…/mail` | `mail-restic-password` | `mail-restic-ssh-key` |
| mc1  | `…/minecraft` | `mc1-restic-password` | `mc1-restic-ssh-key` |
