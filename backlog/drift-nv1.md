# drift-nv1

## what
nv1 deployed closure ≠ declared (origin/main@5aec19d).

`kin status --json` @ 2026-04-12T18:20Z:
```
have:   (unprobeable — proxyJump=relay1 fails, see ops-worker-ssh-reauth.md)
want:   /nix/store/a0zsa8v9qc7v9yhkfp05fbxharjyyn0m-nixos-system-nv1-26.05.20260409.4c1018d
health: not-on-mesh
```
Last confirmed have @ 9403a95 (2026-04-11):
`www09p3bx…-nixos-system-nv1-26.05.20260409.4c1018d` (have==want
then). want has since changed via d90e847 + c9491bc.

## why
Since e196255 deploy:
- d90e847 — kin/iets/nix-skills/llm-agents bump + gen/* regen (all hosts)
- c9491bc — modules/home/desktop: swap 4 llm-agents pkgs → nixpkgs
  (nv1-only, desktop tag)

Same nixpkgs (4c1018d). Drift is internal-input bump + the desktop
pkgs swap.

## reconcile
`kin deploy nv1` (human-gated, mesh-connected machine). Fold into
needs-human/ops-deploy-nv1.md — that file already carries the
runtime-checks list (NPU/ptt-dictate/ask-local/…) which still need a
desk walk; this drift adds two more commits to the deploy scope but no
new runtime checks.

## blockers
- ops-* (human at nv1 or mesh-connected)
- Probe blocked: relay1 proxyJump auth fails (ops-worker-ssh-reauth.md).
  Prior chicken-and-egg (hostcert IPv6 principal) was resolved @
  9403a95; this is a new, separate blocker.
