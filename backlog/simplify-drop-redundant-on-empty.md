# kin.nix:15 — drop redundant `on = [ ]` on zimbatm-yk

## What

```diff
-  users.zimbatm-yk = { admin = true; recipientOnly = true; on = [ ]; };  # YubiKey age recipient (no unix account)
+  users.zimbatm-yk = { admin = true; recipientOnly = true; };  # YubiKey age recipient (no unix account)
```

## Why

kin@5d387b8 made `users.*.on` default to `[]` when `recipientOnly = true`.
flake.lock kin = f4f545d (past 5d387b8, verified `merge-base --is-ancestor`).
Explicit `on = [ ]` is now noise.

Carried over from `tried/drift-eval-broken-recipientonly.md` ("fold into the
next simplifier round") — that branch was abandoned when gate was RED on
storagebox-creds. Gate is GREEN since 5e05dbf.

## How much

One-line edit. Gate: all 3 hosts eval (kin schema accepts the omission).

## Blockers

None. Touches kin.nix (spine) — own round, don't bundle.
