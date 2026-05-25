# Migrating SSH from YubiKey-SK to TPM-backed (nv1)

Why: the YubiKey-SK path needs a per-call SSH_ASKPASS+DISPLAY coercion
to coax the askpass dialog up, and "agent refused operation" failures
are frequent. ssh-tpm-agent signs silently using nv1's TPM 2.0 — no
askpass dance, no touch.

The YubiKey stays in `authorized_keys` alongside the TPM key so it
remains usable from other devices.

## Prereqs (one-time)

After the `keys/`-refactor + `ssh-tpm-agent` home-manager service land
(commit `fa284b0`), rebuild nv1 once:

```bash
, nixos-rebuild switch --flake .#nv1 --sudo
```

This installs `ssh-tpm-agent` and the user systemd unit. It does NOT
yet replace `SSH_AUTH_SOCK` in your current shell; log out + back in
(or `systemctl --user daemon-reload && systemctl --user start
ssh-tpm-agent.service`) to start the agent.

Verify:

```bash
systemctl --user status ssh-tpm-agent.service
ls -la "$XDG_RUNTIME_DIR/ssh-tpm-agent.sock"
echo "$SSH_AUTH_SOCK"   # should point at the agent's socket in a new shell
```

## Generate the TPM key

```bash
ssh-tpm-keygen -t ecdsa -f ~/.ssh/id_ecdsa_tpm
# follow prompts; passphrase optional (TPM seals the key to nv1 already)
```

This writes:
- `~/.ssh/id_ecdsa_tpm.tpm` — the TPM-sealed key blob (private; stays on nv1)
- `~/.ssh/id_ecdsa_tpm.pub` — the public key

## Load into the agent — with per-use confirmation

```bash
ssh-tpm-add -c ~/.ssh/id_ecdsa_tpm.tpm
ssh-add -L                       # should now list the TPM key
```

The `-c` flag (ssh-tpm-agent ≥0.9.0) requires an `ssh-askpass` click
before every signing. The askpass dialog displays the requesting
process chain (e.g. `nixos-rebuild → nix-copy-closure → ssh`), so you
see exactly what's asking before approving — same security property
`rich-ssh-agent` provides, just via TPM instead of YubiKey.

If you instead want silent signing (no per-use confirm), omit `-c`.
Keep in mind that with silent signing, any malicious process on nv1
with access to `$XDG_RUNTIME_DIR` can ask the agent to sign deploys
without your awareness.

## Distribute the public key

```bash
install -m 0644 ~/.ssh/id_ecdsa_tpm.pub ~/go/src/github.com/zimbatm/home/keys/zimbatm-nv1-tpm.pub
```

The path `keys/zimbatm-nv1-tpm.pub` is read by
`modules/nixos/zimbatm.nix` and merged into every host's
`authorized_keys.keys` for both `zimbatm` and `root` (the file is
optional — hosts without it just stay YubiKey-only).

## One last YubiKey-touch deploy round

Touch the YubiKey one more time to push the new `authorized_keys` to
each remote host. This still goes through `rich-ssh-agent` because the
TPM key isn't yet on the remote hosts:

```bash
for host in chat web2 mail mc1 agents; do
  nix run --offline nixpkgs#nixos-rebuild -- switch \
    --flake .#$host --target-host root@$host.ztm.io --use-substitutes
done
```

(Adjust the per-host target hostname — `gts.zimbatm.com` for web2 etc.)

After this round, prefix subsequent deploys with `tpm` (the shell
alias defined in the home-manager module) to route through
`ssh-tpm-agent` and skip the touch:

```bash
tpm nixos-rebuild switch --flake .#agents --target-host root@agents.ztm.io --use-substitutes
```

The `tpm` alias just sets `SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-tpm-agent.sock`
for the single command — `rich-ssh-agent` stays the global default so
sudo/pam_rssh and other YubiKey-required flows are unaffected.

## Verification

```bash
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ecdsa_tpm.pub zimbatm@agents.ztm.io 'echo hi'
# Should print "hi" with no prompt.
```

## Rollback / fallback

Delete `keys/zimbatm-nv1-tpm.pub` and re-deploy the affected host. The
YubiKey path resumes as the only SSH credential. The TPM key on disk
stays; you can re-publish it later.

If `ssh-tpm-agent.sock` is broken / missing, you can still SSH using
the YubiKey path by overriding the env: `SSH_AUTH_SOCK=$(gpg-agent
…socket-path) ssh …`, or `unset SSH_AUTH_SOCK` and let your normal
gpg/gnome-keyring path take over.

## Future: drop the YubiKey from servers entirely

Once you're confident in the TPM path (a few weeks of daily use,
incl. an unexpected reboot), edit `modules/nixos/zimbatm.nix` to drop
the `zimbatm-p1` entry from `zimbatmKeys`. The YubiKey will still work
locally on nv1 (sudo via pam_rssh, FIDO2 for other contexts), just no
longer for these hosts.
