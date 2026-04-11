# grind worker lost ssh to relay1/web2 (regression)

**What:** `kin status` from the grind worker now returns
`health=unreachable` for relay1 and web2. `kin ssh` shows the cause:
`root@95.216.188.155: Permission denied (publickey)` (same for
89.167.46.118). nv1 remains mesh-ULA-only (`Network is unreachable`;
accepted per 723acbc).

**Why it matters:** drift-checker can no longer read
`/run/current-system` on any host, so have-vs-want is blind. 4d6d7bc
closed `ops-grind-fleet-access` after verifying `claude` ssh worked on
both servers; 7a651c4 (last drift-check) still read have/want fine.
Access broke between 7a651c4 and 2a6ea95 — the window where relay1/web2
were redeployed with the assise:// identity rotation (e3e0cf0, b02ea88,
709f1ed; "sibling deploy" per 7aea1fe).

**Likely cause:** the grind worker's ssh-agent only carries the coder
git-signing key (`SHA256:WBaMevQ2…`), not the `claude@kin-infra` key
declared at kin.nix:18. Either the private half was never persisted to
the worker env (and 7a651c4 ran from a session that had it loaded
ad-hoc), or the redeploy dropped a previously-authorized key.

**How much (human, ~10 min):** pick one —
- load the `claude@kin-infra` private key into the grind worker's
  agent (and persist it via whatever provisions `~/.ssh/` here), or
- add the coder key fingerprint to `kin.nix` `sshKeys` and redeploy, or
- have grind-base.js `kin login` a CA-signed cert before drift-check.

**Verify fixed:** from `_base`, `kin status --json relay1 web2` shows
non-empty `have` for both.

**Meanwhile (inferred drift, unverified):** nv1 was deployed at
`i4yx1sbx…` (7aea1fe, 2026-04-11 11:55); current want @ 2a6ea95 is
`hmkplw77…` — stale by the 2a6ea95 kin bump (attest→builtin).
relay1/web2 were deployed pre-2a6ea95 per 7aea1fe, so same applies.
Reconcile once access is back: `kin deploy @all`.
