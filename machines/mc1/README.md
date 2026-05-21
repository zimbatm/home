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

| World         | Port  | Wake mode |
|---------------|-------|-----------|
| `bridge`      | 25565 | always-on |
| `manor`       | 25566 | lazymc    |
| `restaurant`  | 25567 | lazymc    |
| `tvgirl`      | 25568 | lazymc    |
| `galaxi`      | 25569 | lazymc    |
| `GALAXI`      | 25570 | lazymc    |
| `GAMBLING`    | 25571 | lazymc    |
| `hero`        | 25572 | lazymc    |
| `LOVE`        | 25573 | lazymc    |
| `mind`        | 25574 | lazymc    |
| `death`       | 25575 | lazymc    |
| `for`         | 25576 | lazymc    |
| `idk`         | 25577 | lazymc    |
| `New`         | 25578 | lazymc    |
| `manor(1)`    | 25579 | lazymc    |

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

# Push each save into the matching world dir. Note: dir name inside the
# world dir must match the original (it's what level-name= points at).
for w in bridge manor restaurant tvgirl galaxi GALAXI GAMBLING hero LOVE \
         mind death for idk New 'manor(1)'; do
  short=$(echo "$w" | tr '[:upper:]()' '[:lower:]__' | sed 's/_$//')
  case "$w" in
    bridge|manor|restaurant|tvgirl|galaxi|hero|mind|death|for|idk) short="$w" ;;
    GALAXI) short=galaxi2 ;;
    GAMBLING) short=gambling ;;
    LOVE) short=love ;;
    New) short=new ;;
    'manor(1)') short=manor2 ;;
  esac
  rsync -a "/tmp/mc-extract/minecraft/saves/$w/" \
    "root@mc1:/var/lib/minecraft/worlds/$short/$w/"
done

ssh root@mc1 'chown -R minecraft:minecraft /var/lib/minecraft/worlds'
```

(Save names with `(` / case-only collisions go to a sanitized short name
for the service unit; the inner dir keeps the original name so
`level-name` resolves.)

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
