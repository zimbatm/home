# mc1 — personal Minecraft host

NeoForge 1.21.8 modded server (mods + neoforgeServer derivation pulled
from `github:numtide/numcraft`). One always-on **bridge** world on
`mc.ztm.io:25565`; the other 14 worlds each get their own port and sit
asleep until someone connects, courtesy of `lazymc`.

## Layout

```
/var/lib/minecraft/
├── mods/         # nix-store symlinks, rebuilt every activation
├── libraries/    # -> ${neoforgeServer}/lib
└── worlds/
    ├── bridge/
    │   ├── server.properties   # rewritten by Nix
    │   ├── whitelist.json      # rewritten by Nix (from numcraft)
    │   ├── ops.json            # rewritten by Nix
    │   ├── eula.txt
    │   ├── mods -> ../../mods
    │   └── bridge/             # WORLD DATA — upload manually
    ├── manor/
    │   └── manor/              # WORLD DATA
    └── ...
```

The world data dir name *inside* each world dir matches the original save
name from the zip — that's what `level-name=` points at. Don't rename it.

## World <-> port mapping

| Save dir from zip     | Short / service name | Port  | Wake mode |
|-----------------------|----------------------|-------|-----------|
| `bridge`              | `bridge`             | 25565 | always-on |
| `manor`               | `manor`              | 25566 | lazymc    |
| `manor(1)`            | `manor-1`            | 25567 | lazymc    |
| `restaurant`          | `restaurant`         | 25568 | lazymc    |
| `tvgirl`              | `tvgirl`             | 25569 | lazymc    |
| `GALAXI`              | `galaxi`             | 25570 | lazymc    |
| `galaxi (1)`          | `galaxi-1`           | 25571 | lazymc    |
| `GAMBLING`            | `gambling`           | 25572 | lazymc    |
| `hero`                | `hero`               | 25573 | lazymc    |
| `LOVE IN BOTTLE`      | `love-in-bottle`     | 25574 | lazymc    |
| `mind electric`       | `mind-electric`      | 25575 | lazymc    |
| `death`               | `death`              | 25576 | lazymc    |
| `for mother`          | `for-mother`         | 25577 | lazymc    |
| `idk`                 | `idk`                | 25578 | lazymc    |
| `New World`           | `new-world`          | 25579 | lazymc    |
| `New World (1)`       | `new-world-1`        | 25580 | lazymc    |
| `New World (2)`       | `new-world-2`        | 25581 | lazymc    |
| `New World (3)`       | `new-world-3`        | 25582 | lazymc    |
| `New World (4)`       | `new-world-4`        | 25583 | lazymc    |
| `New World (5)`       | `new-world-5`        | 25584 | lazymc    |

Voicechat: UDP 24454 (shared across all worlds).

## Bootstrap

### 1. Provision the box

Order a Hetzner Cloud cx42 in fsn1 with a recent Debian image. SSH in as
root, then from your laptop:

```sh
nix run github:nix-community/nixos-anywhere -- \
  --flake .#mc1 root@<ip>
```

### 2. Grab the host pubkey and rewire secrets

```sh
ssh root@<ip> 'cat /etc/ssh/ssh_host_ed25519_key.pub'
# Paste into secrets/secrets.nix (uncomment the `mc1 = ...` line and
# add `mc1` to mc1Hosts), then re-encrypt:
agenix -r
```

### 3. Encrypt the restic creds

```sh
agenix -e secrets/mc1-restic-password.age   # paste a long random string
agenix -e secrets/mc1-restic-ssh-key.age    # paste the rsync.net ed25519 priv key body
```

Reuse the same rsync.net account key as chat/mail.

### 4. Upload world data

```sh
# Extract once locally
unzip -q ~/Downloads/minecraft.zip -d /tmp/mc-extract

# (dir from zip) → (short name in configuration.nix). Mapped by hand
# because the zip has spaces, parens, and case-only collisions that
# don't sanitize cleanly with a one-liner.
declare -A worlds=(
  ["bridge"]="bridge"
  ["manor"]="manor"
  ["manor(1)"]="manor-1"
  ["restaurant"]="restaurant"
  ["tvgirl"]="tvgirl"
  ["GALAXI"]="galaxi"
  ["galaxi (1)"]="galaxi-1"
  ["GAMBLING"]="gambling"
  ["hero"]="hero"
  ["LOVE IN BOTTLE"]="love-in-bottle"
  ["mind electric"]="mind-electric"
  ["death"]="death"
  ["for mother"]="for-mother"
  ["idk"]="idk"
  ["New World"]="new-world"
  ["New World (1)"]="new-world-1"
  ["New World (2)"]="new-world-2"
  ["New World (3)"]="new-world-3"
  ["New World (4)"]="new-world-4"
  ["New World (5)"]="new-world-5"
)

for dir in "${!worlds[@]}"; do
  short="${worlds[$dir]}"
  rsync -a "/tmp/mc-extract/minecraft/saves/$dir/" \
    "root@mc1:/var/lib/minecraft/worlds/$short/$dir/"
done

ssh root@mc1 'chown -R minecraft:minecraft /var/lib/minecraft/worlds'
```

The inner dir keeps the original name (including spaces/parens) because
that's what `level-name=` in server.properties points at.

### 5. DNS

Point `mc.ztm.io` A/AAAA at the mc1 IPs. Friends connect to
`mc.ztm.io` (lands in bridge) or `mc.ztm.io:25566` etc. for a specific
world. Their PrismLauncher already has the mod set if they're on numcraft
client.

### 6. Activate

```sh
nixos-rebuild switch --flake .#mc1 --target-host root@mc1
```

`bridge` should come up; the others stay asleep until someone connects.

## Whitelist

Pulled from `numcraft/whitelist.toml` at flake-input eval time. To add
someone, get them merged into numcraft and `nix flake update numcraft`
here. To run a totally separate whitelist, replace the `whitelistEntries`
in `configuration.nix` with a local TOML/JSON.

## Why no Velocity proxy?

You asked for "bridge world + on-demand maps". The natural Velocity
answer (lobby + `/server <name>`) is fragile against modded NeoForge —
modern forwarding wants matching mod-side support that has shipped
slowly. For a 7-person whitelist, "first server in the multiplayer list"
gives you the same lobby UX without the proxy. We can add Velocity later
if cross-world chat or seamless transfer becomes worth the hassle.
