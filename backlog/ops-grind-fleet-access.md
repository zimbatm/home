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
