# Stand up the `ztm` tincr mesh

Private backplane between nv1, chat, web2, mail, mc1, agents at
`10.42.0.10–15` on subnet `10.42.0.0/24`. Static `Address=` peering;
`chat` + `web2` are bootstraps. Reach peers internally as
`<peer>.ztm` (injected into each host's `/etc/hosts`).

## What's already in the repo

- `flake.nix` input `tincr` (Mic92's Rust rewrite of tinc 1.1).
- `modules/nixos/tinc-ztm.nix`: shared module, looks up the local IP
  by `networking.hostName`, reads peer pubkeys from
  `tinc/hosts/<name>`, reads its own private key from agenix.
- Module is NOT yet imported by any host — adding the import is the
  last step below, after keys exist.

## Phase 2 — keys + wiring

### 1. Generate one Ed25519 keypair per host (×6)

Use `sptps_keypair` from the tincr package. On nv1:

```bash
KEYS=$(mktemp -d) && cd "$KEYS"
for n in nv1 chat web2 mail mc1 agents; do
  nix run github:Mic92/tincr#tincd -- -n ztm -K --bootstrap-dir="$KEYS/$n" >/dev/null
  # produces $KEYS/$n/ed25519_key.priv and ed25519_key.pub
done
ls */ed25519_key.{priv,pub}
```

(If `tincd -K` isn't the right invocation in your tincr version, fall
back to `sptps_keypair $KEYS/$n/ed25519_key.priv $KEYS/$n/ed25519_key.pub`.)

### 2. Commit the public halves

Each host's `tinc/hosts/<name>` file collects everyone's `Subnet=`,
the host's public `Address=` (skip for nv1, it's behind NAT), and its
`Ed25519PublicKey=`. From the `$KEYS` dir:

```bash
mkdir -p ~/go/src/github.com/zimbatm/home/tinc/hosts
declare -A IP=(
  [nv1]=10.42.0.10 [chat]=10.42.0.11 [web2]=10.42.0.12
  [mail]=10.42.0.13 [mc1]=10.42.0.14 [agents]=10.42.0.15
)
declare -A ADDR=(
  [chat]=chat.ztm.io        [web2]=gts.zimbatm.com
  [mail]=mail.zimbatm.com   [mc1]=mc.ztm.io
  [agents]=agents.ztm.io
)
for n in nv1 chat web2 mail mc1 agents; do
  {
    [ -n "${ADDR[$n]:-}" ] && echo "Address = ${ADDR[$n]}"
    echo "Subnet = ${IP[$n]}/32"
    cat "$KEYS/$n/ed25519_key.pub"
  } > ~/go/src/github.com/zimbatm/home/tinc/hosts/$n
done
```

### 3. Encrypt private keys via agenix

Each private key is encrypted to zimbatm + the target host's
ssh-ed25519 host key (so only the right machine can decrypt). Add the
6 entries to `secrets/secrets.nix`:

```nix
"tinc-ztm-nv1-key.age".publicKeys    = [ zimbatm ];   # nv1 has no host key in this manifest
"tinc-ztm-chat-key.age".publicKeys   = chatHosts;
"tinc-ztm-web2-key.age".publicKeys   = web2Hosts;
"tinc-ztm-mail-key.age".publicKeys   = mailHosts;
"tinc-ztm-mc1-key.age".publicKeys    = mc1Hosts;
"tinc-ztm-agents-key.age".publicKeys = agentsHosts;
```

Then encrypt:

```bash
for n in nv1 chat web2 mail mc1 agents; do
  # The recipients list matches secrets/secrets.nix above. The exact
  # `-r` args are easier to hand-type from the resolved set, or use
  # `agenix -e` if it works in your shell.
  age -e \
    -r age1tk655t40a4zx7ry0mzj57vmw4xpr7sa0c8qnckmclj5gzjls4yzsk7weg0 \
    [-r '<host-pubkey-from-secrets.nix>'] \
    -o ~/go/src/github.com/zimbatm/home/secrets/tinc-ztm-$n-key.age \
    "$KEYS/$n/ed25519_key.priv"
done
shred -u $KEYS/*/ed25519_key.priv && rm -rf "$KEYS"
```

### 4. Import the module from each host

Add to each of `machines/{nv1,chat,web2,mail,mc1,agents}/configuration.nix`:

```nix
imports = [
  ...
  inputs.self.nixosModules.tinc-ztm
];
```

### 5. Deploy

```bash
# nv1 first (local)
, nixos-rebuild switch --flake .#nv1 --sudo

# remotes
for host in chat web2 mail mc1 agents; do
  case "$host" in
    web2) tgt=gts.zimbatm.com ;;
    mail) tgt=mail.zimbatm.com ;;
    mc1)  tgt=mc.ztm.io ;;
    *)    tgt=$host.ztm.io ;;
  esac
  nix run --offline nixpkgs#nixos-rebuild -- switch \
    --flake .#$host --target-host root@$tgt --use-substitutes
done
```

### 6. Verify

From any host:

```bash
ip -br addr show tinc.ztm                                  # 10.42.0.X/24
tinc -n ztm dump nodes                                     # 6 nodes
tinc -n ztm dump connections                               # 2+ edges from each
ping -c2 chat.ztm   ping -c2 web2.ztm   ping -c2 mail.ztm
ping -c2 mc1.ztm    ping -c2 agents.ztm
```

## What stays public for now

This mesh adds a path; it doesn't remove existing public exposure.
Each internal service still listens where it does today
(`agents.ztm.io` on the Internet, mail SMTP on 25, etc.). To migrate
a service to mesh-only:

1. Change its NixOS module to bind on the tinc IP (`10.42.0.X`) or
   `0.0.0.0` with a firewall rule restricted to `10.42.0.0/24`.
2. Drop the public firewall hole for that port.
3. Update any `.ztm.io` clients to use `<peer>.ztm` instead.

Candidates worth migrating once the mesh is verified: Stalwart admin
API, healthchecks UI (if/when self-hosted), the ttyd web terminal.
