# drift-web2

## what
web2 deployed closure ≠ declared (origin/main@5aec19d).

`kin status --json` @ 2026-04-12T18:20Z:
```
have:   (unprobeable — see ops-worker-ssh-reauth.md)
want:   /nix/store/2dfri5fhlsm488qknfvwkg1akr15frgm-nixos-system-web2-26.05.20260409.4c1018d
health: unreachable (ssh: Permission denied (publickey))
```
Host pings (105ms); sshd up; auth fails. Last confirmed have==want @
9403a95 (2026-04-11) — closure since superseded by d90e847.

## why
Same as drift-relay1.md: d90e847 (kin/iets/nix-skills/llm-agents bump
+ gen/* regen) landed after last deploy. web2 runs `services.attest`
so the regenerated identity certs + attest signing-key path matter.
Same nixpkgs (4c1018d).

## reconcile
Just deploy: `kin deploy web2` (human-gated). Gate passed @ d90e847.

## blockers
- ops-* (human runs deploy)
- Probe blocked by ops-worker-ssh-reauth.md.
