# Provision a new Hetzner Cloud host

End-to-end: API create → NixOS install → wire into flake/agenix → deploy.

## 1. Pick a server type that's actually available

Older `cpx21`, `cpx51`, etc. are deprecated. Check what's available in your target location:

```bash
. .envrc.local
nix run --offline nixpkgs#hcloud -- server-type list \
  --output columns=name,cores,cpu_type,memory,disk,architecture
```

Common picks (as of 2026-05): `cpx22` (2c shared/4GB), `cpx62` (16c shared/32GB),
`ccx33` (8c dedicated/32GB), `ccx43` (16c dedicated/64GB).

⚠️ Dedicated tiers (`ccx*`) require a quota that new accounts don't have — open
a Hetzner support ticket if `dedicated core limit exceeded` blocks you.

## 2. Create the VM

```bash
NAME=NEW_HOST
TYPE=cpx22                  # or whatever step 1 told you
LOC=hel1                    # match where related volumes live
SSH_KEY=zimbatm@p1
nix run --offline nixpkgs#hcloud -- server create \
  --name $NAME --type $TYPE --location $LOC \
  --image debian-12 --ssh-key $SSH_KEY \
  --label role=$NAME --label managed-by=home-flake
nix run --offline nixpkgs#hcloud -- server enable-protection $NAME delete rebuild
```

Note the IPv4 and IPv6 from `hcloud server describe $NAME`.

## 3. Reverse DNS

```bash
nix run --offline nixpkgs#hcloud -- server set-rdns $NAME --ip $V4 --hostname $NAME.ztm.io
nix run --offline nixpkgs#hcloud -- server set-rdns $NAME --ip $V6 --hostname $NAME.ztm.io
```

## 4. Add the machine to the flake

```
machines/$NAME/
  configuration.nix      # start from a similar host (mail or agents)
  disko.nix              # see disk-layout note below
```

In `flake.nix nixosConfigurations`:

```nix
$NAME = lib.nixosSystem {
  system = "x86_64-linux";
  specialArgs = { inherit inputs; };
  modules = [ ./machines/$NAME/configuration.nix ];
};
```

### Disk layout — UEFI vs BIOS

**Newer Hetzner types are UEFI** (`cpx22`, `cpx62`, `ccx*`, `cx42`, `cx52`).
Older `cx23` is BIOS. Symptom of getting this wrong: install completes, VM
reboots, never comes back. Verify in rescue mode with `[ -d /sys/firmware/efi ]`.

UEFI shape — see `machines/mail/disko.nix`: 512 MiB FAT32 ESP at `/boot` + ext4
root. Bootloader: `boot.loader.systemd-boot.enable = true;`.

BIOS shape — see `machines/web2/disko.nix`: 1 MiB `EF02` BIOS-boot + ext4 root.
Bootloader: `boot.loader.grub.enable = true;`.

### Interface name

Newer Hetzner images use `eth0`; older `enp1s0`. Match both:

```nix
systemd.network.networks."05-eth".matchConfig.Name = "enp1s0 eth0";
```

## 5. Install via nixos-anywhere

The SSH key uploaded to Hetzner is the YubiKey-SK. Without a terminal, ssh-agent
needs an askpass to confirm the touch:

```bash
cd ~/go/src/github.com/zimbatm/home
SSH_ASKPASS=/nix/store/h963yim5mc9429i628d0hnhpfvzhlxdr-age-1.3.1/bin/age \
  # ↑ wrong — use the gcr4-ssh-askpass path
SSH_ASKPASS=$(nix path-info nixpkgs#gcr --no-link 2>/dev/null \
  | head -1)/libexec/gcr4-ssh-askpass \
SSH_ASKPASS_REQUIRE=force \
DISPLAY=:0 \
nix run github:nix-community/nixos-anywhere -- --flake .#$NAME root@$V4
```

Touch the YubiKey when the askpass dialog appears.

## 6. Capture the new host's SSH key

After install + reboot:

```bash
ssh -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new root@$V4 \
  'cat /etc/ssh/ssh_host_ed25519_key.pub'
```

Add to `secrets/secrets.nix`:

```nix
$NAME = "ssh-ed25519 AAAA…";
```

## 7. Re-encrypt agenix secrets that this host needs

For each `.age` file the host needs:

```bash
AGE=$(nix path-info nixpkgs#age --no-link 2>/dev/null | head -1)/bin/age
KEY=$HOME/.config/sops/age/keys.txt
R_Z=age1tk655…  # zimbatm
R_NEW="ssh-ed25519 AAAA…"  # the new host
for s in foo bar baz; do
  $AGE -d -i $KEY secrets/$s.age | $AGE -e -r $R_Z -r $R_NEW -o secrets/$s.age.new
  mv secrets/$s.age.new secrets/$s.age
done
```

## 8. Deploy

```bash
NIX_SSHOPTS="-o IdentitiesOnly=yes" \
nix run nixpkgs#nixos-rebuild -- switch --flake .#$NAME --target-host root@$V4 \
  --use-substitutes
```

## 9. DNS via dnscontrol

Add the host to `dns/dnsconfig.js` under the relevant zone, then:

```bash
nix run .#dns-push
```

See [dns.md](dns.md).

## Verify

```bash
ssh -o IdentitiesOnly=yes root@$V4 'hostname; uname -a; systemctl --failed'
```

No failed units, hostname matches, NixOS kernel.
