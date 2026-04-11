# grind worker lost ssh to relay1/web2 (regression)

**What:** `kin status` from the grind worker now returns
`health=unreachable` for relay1 and web2. `kin ssh` shows the cause:
`root@95.216.188.155: Permission denied (publickey)` (same for
89.167.46.118). nv1 remains mesh-ULA-only (`health=not-on-mesh`;
accepted per 723acbc).

**Why it matters:** drift-checker can no longer read
`/run/current-system` on any host, so have-vs-want is blind. 4d6d7bc
closed `ops-grind-fleet-access` after verifying `claude` ssh worked on
both servers; 7a651c4 (last drift-check) still read have/want fine.
Access broke between 7a651c4 and 2a6ea95 — the window where relay1/web2
were redeployed with the assise:// identity rotation (e3e0cf0, b02ea88,
709f1ed; "sibling deploy" per 7aea1fe).

**Root cause (re-diagnosed 2026-04-11 @ a68c5ed):** the worker's
ssh-agent now *does* carry a `claude@kin-infra` key + CA cert (someone
tried the fix) — but **both are from the wrong fleet**:

- agent key `SHA256:d4hLpc9c…` ≠ kin.nix:18 declared key
  `SHA256:q+vuWh4n…` — same comment string, different keypair.
- agent cert is signed by CA `SHA256:tEcTOXmz…` for fleet-id
  `dwqfzbq5…`; **home's** CA is `SHA256:K8GPw7x…` for fleet-id
  `bir7vyhu…` (gen/identity/ca/_shared/ssh-ca.pub).

`ssh -vv` confirms relay1/web2 reject all three offered keys for both
root@ and claude@. The worker provisioning likely ran `kin login` from
`../kin-infra` instead of `../home`.

**How much (human, ~10 min):** pick one —
- run `kin login` **from the home repo** so the cert is signed by
  home's CA `K8GPw7x…`, and persist that key+cert into the worker's
  agent provisioning; or
- replace kin.nix:18 with the agent's actual pubkey
  `ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJeTgAfmrKax1TAMTiv/D8IImSRfnELGamSJvDqfQt21`
  then `kin gen` + `kin deploy relay1 web2` from a session that *can*
  reach them (Jonas's key); or
- load the original `q+vuWh4n…` private key if it still exists.

**Verify fixed:** from `_base`, `kin status --json relay1 web2` shows
non-empty `have` for both.

**Meanwhile (inferred drift, unverified — refreshed @ a68c5ed):**
last known deploys per 7aea1fe were pre-2a6ea95. Current want:
nv1=`81plk14m…` (was `hmkplw77…` @ 2a6ea95; +NPU/ptt-dictate/stateVersion),
relay1=`2pr46yxn…` (unchanged since 2a6ea95), web2=`pp1zqfk6…`
(was `z2linhh7…`). Reconcile once access is back: `kin deploy @all`.
