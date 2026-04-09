# tried: drift-eval-broken-recipientonly

## Outcome
Abandoned at merge gate (2026-04-09). Gate RED on relay1+web2.

## Why abandoned
Branch's substantive work was **superseded** by a12d1ce
(migrate-gen-fleet-core), which bumped kin ba1f278→0d5df8f — already
past a0b42b3 (recipientOnly) and 5d387b8 (on=[] default). The
gen/_fleet/_shared/ migration also landed there.

Residual unique diff after conflict resolution (keep main's newer
flake.lock):
- kin.nix:15 drop redundant `on = [ ];` (kin>=5d387b8 defaults it)
- delete backlog/drift-eval-broken-recipientonly.md (stale; describes
  already-fixed problem)

Gate failed relay1+web2:
`kin: secret user/gotosocial-storagebox-credentials/_shared/credentials
declared but .age missing` — **pre-existing on origin/main@a12d1ce**,
not introduced by this branch (verified: origin/main fails
identically). Surfaced by kin@0d5df8f's stricter declared-secret check;
tracked by ops-storagebox-creds-kin-set.md (human-gated `kin set`).

## Re-attempt when
After ops-storagebox-creds-kin-set.md closes (human provides creds)
and main gate goes GREEN. Then it's a trivial 2-file cleanup; or just
fold into the next simplifier round.

## Note
backlog/drift-eval-broken-recipientonly.md on main is now stale (its
problem is fixed). Next triage should close it independent of the
`on=[]` cleanup.
