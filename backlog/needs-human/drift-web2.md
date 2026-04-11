# web2: declared ≠ deployed (config-side accumulation)

**What:** `kin status web2` @ 6fcd114 reports stale:

- have `/nix/store/pp1zqfk6mk61gbi3g55rdhc8anxi4nfw-nixos-system-web2-26.05.20260409.4c1018d`
- want `/nix/store/y7qa869yz506a3pflj1lyfbkdzi754sr-nixos-system-web2-26.05.20260409.4c1018d`
- health `running`, secrets `active`, uptime 3d6h, failed `-`

Same nixpkgs (`4c1018d`) both sides → drift is repo-local since last
deploy. Last drift probe (92818b4) had have==want=`pp1zqfk6`; deployed
state has nothing the declaration doesn't.

**Diff (commits since 92818b4 touching web2 eval):**

- 9649a5f — kin bump f0f2098→43cfb97
- 23376bf — kin bump 43cfb97→a33a3dc + `kin gen` (web2 ssh-host.cert /
  tls.crt / tls.fullchain / mesh fingerprints regenerated)
- b5e638f — iets bump 11d1e715→e9669508
- 55c4a4d — drop dead `flake=inputs.self` specialArg

**Reconcile:** just deploy. No deployed-only state to preserve. web2
runs `services.attest` (kin.nix:30) — 23376bf's cert regen is relevant
to it; otherwise input-bump hash churn.

**How much:** `kin deploy web2` — human-gated per CLAUDE.md.

**Blockers:** human at keyboard.
