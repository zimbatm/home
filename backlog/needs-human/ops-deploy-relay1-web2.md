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
web2   want: /nix/store/zkmps922d28s796avisdfg4jk4mdynfy-nixos-system-web2-26.05.20260409.4c1018d
have:        unprobeable (ssh publickey denied — ops-worker-ssh-reauth.md)
```

(web2 want refreshed @ 93e01e7 — 0d2890f kin/iets bump + 0a84820 srvos
bump moved web2 `5fb4q6zr…`→`zkmps922…`; relay1 unchanged across both,
minimal mesh-relay closure pulls neither srvos nor the bumped kin/iets
surface.)

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

---

## drift @ 41238a4 (2026-04-12)

Probe still blind (ops-worker-ssh-reauth.md). want refreshed:

```
relay1 want: /nix/store/l7h41cp7ixdrhgbw71k75bplqdiip87h-nixos-system-relay1-26.05.20260409.4c1018d  (unchanged since 93e01e7)
web2   want: /nix/store/ljkny7sl99ymdljs2c913qpjkkwm9p0z-nixos-system-web2-26.05.20260409.4c1018d  (was zkmps922…)
```

relay1 closure-neutral across all 6 nix-touching commits 93e01e7..HEAD
(minimal mesh-relay surface pulls neither kin/iets bump nor crops-demo
lock growth). web2 moved via 3ae52ac (kin/iets internal bump —
services.attest surface) and/or d4e1fea (crops-demo input add, lock
19→32 nodes). No service-shape changes; reconcile unchanged.

---

## drift @ e8c0ad4 (2026-04-12)

Probe still blind (ops-worker-ssh-reauth.md — `kin status --json`
returns `unreachable`, have empty). want refreshed:

```
relay1 want: /nix/store/l7h41cp7ixdrhgbw71k75bplqdiip87h-nixos-system-relay1-26.05.20260409.4c1018d  (unchanged since 93e01e7)
web2   want: /nix/store/z5sq8m0z0ymk40bszmg6clp4wlx6d0ca-nixos-system-web2-26.05.20260409.4c1018d  (was ljkny7sl…)
```

relay1 still closure-neutral across 41238a4..e8c0ad4 (5 nix-touching
commits: fc83166/0d0321d/ffef511 nv1-only; dc59a67 kin/iets bump
doesn't reach minimal mesh-relay surface; c27c5c1 follows-dedupe
drvPath-identical). web2 moved via dc59a67 only (kin 69dbf2a→12d99c5,
iets 7d651f2→8259dcd — services.attest + common surface). No
service-shape changes; reconcile unchanged. Gate passed @ dc59a67
(eval+dry-build green per bumper commit).
