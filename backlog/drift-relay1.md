# drift-relay1

## what
relay1 deployed closure ≠ declared (origin/main@5aec19d).

`kin status --json` @ 2026-04-12T18:20Z:
```
have:   (unprobeable — see ops-worker-ssh-reauth.md)
want:   /nix/store/l7h41cp7ixdrhgbw71k75bplqdiip87h-nixos-system-relay1-26.05.20260409.4c1018d
health: unreachable (ssh: Permission denied (publickey))
```
Host pings (105ms); sshd up; auth fails both as claude@ and root@.
Last confirmed have==want @ 9403a95 (2026-04-11) — closure since
superseded by d90e847.

## why
d90e847 landed after last deploy: kin 2674774→78fc89d (+525c, mesh
keep_addr_on_down sysctl + tun inline-table + relay non-member throw),
iets e966950→264974e (+317c), nix-skills/llm-agents bumps; `kin gen`
regenerated identity/machine/relay1/{ssh-host.cert,tls.crt,tls.fullchain}
+ mesh/fingerprints + manifest.lock. c9491bc swapped 4 llm-agents pkgs
→ nixpkgs (desktop-only, relay1 unaffected). Same nixpkgs (4c1018d).

Cannot run `nix store diff-closures` — `have` not readable from this
worker (auth break, ops-worker-ssh-reauth.md). Structural diff = the
d90e847 gen/* + flake.lock delta.

## reconcile
Just deploy: `kin deploy relay1` (human-gated). Expected low risk —
gate passed (eval+dry-build ✓ @ d90e847), diff is the reviewed
internal-input bump. relay1 is `services.mesh.relay` so the kin mesh
changes (fb75ce2/907a3e2/b886b6a) land here first.

## blockers
- ops-* (human runs deploy)
- Probe blocked: worker ssh key rotated overnight, see
  ops-worker-ssh-reauth.md — fix that first if you want `have`
  confirmed pre-deploy.
