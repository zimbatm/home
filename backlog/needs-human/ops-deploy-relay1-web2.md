# ops: deploy relay1 + web2 (drift since e196255)

**needs-human** — `kin deploy` is human-gated; probe also blocked on
ops-worker-ssh-reauth.md.

## what
Both hosts' deployed closure ≠ declared. Last confirmed have==want @
9403a95 (2026-04-11). Since then d90e847 landed undeployed (kin
2674774→78fc89d +525c, iets +317c, nix-skills/llm-agents bumps; `kin
gen` regenerated identity/{ssh-host.cert,tls.crt,tls.fullchain} +
mesh/fingerprints + manifest.lock). Same nixpkgs (4c1018d). Subsequent
rounds added f7eaa19 (treefmt-nix input) + 7d092c5/b1f1bb3 lock bumps.

```
relay1 want: /nix/store/l7h41cp7ixdrhgbw71k75bplqdiip87h-nixos-system-relay1-26.05.20260409.4c1018d
web2   want: /nix/store/5fb4q6zrdq00k6984lvj06wbks8kl6x0-nixos-system-web2-26.05.20260409.4c1018d
have:        unprobeable (ssh publickey denied — ops-worker-ssh-reauth.md)
```

(web2 want corrected @ 30b8cf5 — meta-fold had carried forward the
stale `2dfri5fh…` from e0f586d's eval @ 5aec19d; the f7eaa19/b1f1bb3/
7d092c5 bumps it already cites moved web2 but not relay1.)

web2 runs `services.attest` so the regenerated identity certs + attest
signing-key path matter.

## reconcile
`kin deploy relay1 && kin deploy web2` from a host with working ssh
(Jonas's zimbatm key still trusted). Gate passed @ d90e847+f7eaa19
(eval+dry-build green). Low risk — diff is reviewed kin/iets bumps +
gen/* regen, no service-shape changes.

## why folded here (meta round 8)
drift-{relay1,web2}.md cycled 3×A/2×D through backlog/ (7a651c4→0b1f2e7→
8f9d4de→815cf92→e0f586d). Same treatment as drift-nv1 → ops-deploy-nv1
@ 39bab6b: deploy-only + probe-blind items belong in needs-human/, not
re-triaged each round. drift-checker re-files after next deploy if gap
reopens.
