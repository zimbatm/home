# Migrate a Hetzner Cloud Volume between hosts

The volume must stay in the same Hetzner location — fsn1 volumes attach only
to fsn1 servers, hel1 to hel1.

## 0. Pre-flight

- Confirm both source and destination NixOS configs reference the volume
  via `/dev/disk/by-id/scsi-0HC_Volume_<id>` (the by-id path doesn't change
  across attach).
- The destination config should already declare the `fileSystems` entry
  (with `nofail` so it can boot before the volume's attached).

## 1. Insurance snapshot

Hetzner doesn't expose volume snapshots via the API. Tar to local disk:

```bash
ssh root@$SOURCE 'tar -cf /root/$NAME-pre-cutover.tar -C /var/lib $NAME'
ssh root@$SOURCE 'ls -lh /root/$NAME-pre-cutover.tar'
```

This eats a few GB on the source's root disk — clean up after cutover.

## 2. Stop the service that owns the volume

```bash
ssh root@$SOURCE 'systemctl stop $SERVICE'
```

## 3. Unmount + detach

```bash
ssh root@$SOURCE 'umount /var/lib/$NAME'
nix run --offline nixpkgs#hcloud -- volume detach $VOLUME_NAME
```

## 4. Attach to destination

```bash
nix run --offline nixpkgs#hcloud -- volume attach $VOLUME_NAME --server $DEST
```

## 5. Mount + start on destination

```bash
ssh root@$DEST '
  systemctl daemon-reload
  systemctl start var-lib-$NAME.mount
  mountpoint /var/lib/$NAME
  systemctl start $SERVICE
'
```

## 6. Smoke-test

Hit the service's protocol-level endpoint and confirm it reads/writes
the migrated state correctly.

## 7. Clean up the tar after a week

```bash
ssh root@$SOURCE 'rm /root/$NAME-pre-cutover.tar'
```

## When to use this vs. just rsync

- Volume reattach: atomic at the storage layer, no copy time, only same-DC.
- rsync: works cross-DC and cross-provider, but slow for large data.
