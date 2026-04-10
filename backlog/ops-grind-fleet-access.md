# Grind drift-checker has no fleet access

**What:** `/grind` drift-checker can't compare declared vs deployed on
any host. From the grind container at origin/main (49a4aa2, 2026-04-08):

```
$ kin status
  ?  nv1     —   not-on-mesh  CalledProcessError
  ?  relay1  —   unreachable  CalledProcessError
  ?  web2    —   unreachable  CalledProcessError
```

Per-host:
- nv1 (`fd18:cb0b:6a1d::6e42:b995:2026:deae`): `Network is unreachable`
  — grind container isn't a maille mesh member.
- relay1 (`95.216.188.155`): `Permission denied (publickey)` — host
  reachable, agent key not authorized.
- web2 (`89.167.46.118`): `Permission denied (publickey)` — same.

Agent key (not in `kin.nix` sshKeys):
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILJiqcngEVXnTuaT44BbahCf4teIM2mMHyvly+GvmEUf jonas@kin-infra
```

**Why:** drift-checker is one of three `/grind` specialists (a8a11c7).
Without fleet reach it produces nothing every tick. relay1/web2 are one
key-enroll away from working; nv1 needs mesh or a public-reachable
fallback addr.

**How much:** human decides scope, then:
- minimal: add agent pubkey to `kin.nix` sshKeys + `kin deploy relay1
  web2` → drift works for the two servers (nv1 stays unreachable, which
  is acceptable — desktop, often off).
- full: also enroll grind container as a maille member so nv1 is
  reachable when up.

**Blockers:** needs-human — `kin deploy` and key-trust decisions are
out of grind's remit.

**Falsifies:** once landed, `kin status` from grind should show real
toplevel hashes for relay1/web2 instead of `?  —`.
**Re-check (drift-check 2026-04-09 @ e10abeb, homespace):** still
blocked — relay1/web2 `Permission denied (publickey)`, nv1
`Network is unreachable` (mesh-only). The homespace grind container
offers a *different* key than the kin-infra one above:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGYeUGfaTosjlkPT/DVb3nuvPcw1ivEtIx5bcxIyqpd/ coder@homespace
```
Enroll **both** (or whichever env runs drift going forward) — adding
only the kin-infra key won't unblock the homespace runner. nv1 desired
toplevel at this HEAD: drv `g1allrvy…-nixos-system-nv1-26.05.20260405`.

**Re-check (drift-check 2026-04-10 @ 8e60ab1):** still blocked —
relay1/web2 `Permission denied (publickey)` (both `claude@` and
`root@`), nv1 `Network is unreachable`. `~/.ssh/config` now has
`Host nv1 relay1 web2 … User claude IdentityFile ~/.ssh/kin_ed25519`,
so grind-side wiring is ready; only the fleet-side `users.claude`
enroll (`ops-add-claude-deployer.md`) remains. **But** this container's
`~/.ssh/kin_ed25519` is a *third* distinct key:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ4A37V7FWTQgVqVNw+Ub+2AyRAgkll0ZBX6udc/C1E6 claude@kin-infra
```
→ the parked branch's `keys/users/claude.pub` is likely already stale.
Either pin one stable key across grind runners, or enroll all three
observed keys in `users.claude.sshKeys`. Desired toplevels at this
HEAD (all 3 hosts eval clean): nv1 drv `1hs9dndp…`, relay1 drv
`m9knhz82…`, web2 drv `k31jzxp5…` (`nixos-system-*-26.05.20260405`).
flake.lock: all direct inputs ≤7d old, no bump needed.
