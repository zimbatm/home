# relay1: declared ≠ deployed (config-side accumulation)

**What:** `kin status relay1` @ 6fcd114 reports stale:

- have `/nix/store/2pr46yxnbh4vmaxqsx3df820pswlc6vm-nixos-system-relay1-26.05.20260409.4c1018d`
- want `/nix/store/0cq8zp2g9v68vm5xmg83xzqafk071agp-nixos-system-relay1-26.05.20260409.4c1018d`
- health `running`, secrets `active`, uptime 3d4h, failed `-`

Same nixpkgs (`4c1018d`) both sides → drift is repo-local since last
deploy. Last drift probe (92818b4, ~3d ago) had have==want=`2pr46yxn`,
so deployed state is exactly what was declared then; nothing extra on
the box.

**Diff (commits since 92818b4 touching relay1 eval):**

- 9649a5f — kin bump f0f2098→43cfb97
- 23376bf — kin bump 43cfb97→a33a3dc + `kin gen` (relay1 ssh-host.cert /
  tls.crt / tls.fullchain / mesh fingerprints regenerated)
- b5e638f — iets bump 11d1e715→e9669508 (kin.iets follows)
- 55c4a4d — drop dead `flake=inputs.self` specialArg

(Desktop-only commits 8954ef0/80d0d6a/4039530/13d408b/85aed14 are
hm-desktop + packages; relay1 is `tags=["server","relay"]`, no hm.)

`nix store diff-closures` not available — want closure was dry-built
only, not pushed to host.

**Reconcile:** just deploy. No deployed-only state to preserve. The
cert/fingerprint regen (23376bf) is the only functionally interesting
piece; rest is input-bump hash churn.

**How much:** `kin deploy relay1` — human-gated per CLAUDE.md. Confirm
ssh path survives (relay1 is the proxyJump for nv1; lockout-recovery
applies).

**Blockers:** human at keyboard.
