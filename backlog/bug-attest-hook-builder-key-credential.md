# bug: attest post-build-hook can't read builder-key on web2

## What

`kin-attest-publish` hook fails on web2: "ietsd attest-log publish:
--key /run/credentials/nix-daemon.service/builder-key: No such file or
directory". The `|| true` swallows it (build succeeds) but no
attestation is published — web2's attest-log stays empty.

Seen 2026-04-11 G2 falsification (hello build).

## Why

`services/attest.nix` sets `systemd.services.nix-daemon` LoadCredential
for builder-key, but either:
- nix-daemon wasn't restarted after the deploy (LoadCredential is read
  at service start)
- the source path in LoadCredential doesn't match the kin-secrets
  decrypted location on home's runtime layout
- post-build-hook runs as a separate process with a different
  CREDENTIALS_DIRECTORY

## Fix

Probe `systemctl show nix-daemon -p LoadCredential` + `ls
/run/credentials/nix-daemon.service/`. If LoadCredential is set but dir
empty: `systemctl restart nix-daemon`. If source path wrong: fix
attest.nix LoadCredential to point at home's actual decrypted-secret
path.
