# fix: silence hm `programs.firefox.configPath` eval warning

## What

22bbd1c bumped home-manager 6f59831b→c55c498c. nv1 eval now emits a
warning on every `nix eval`/`kin gen`:

```
zimbatm profile: The default value of `programs.firefox.configPath` has
changed from ".mozilla/firefox" to "${config.xdg.configHome}/mozilla/firefox".
You are currently using the legacy default because home.stateVersion < "26.05".
```

relay1/web2 unaffected (no home-manager).

## Why

Noisy eval output pollutes drift/grind logs; warning will repeat
forever until pinned. Decision needed: keep legacy path (zero
migration) or move to XDG (requires moving `~/.mozilla/firefox` on the
running nv1 — human-gated, profile data at risk).

## How much

One line in `modules/home/desktop/default.nix:36` next to
`programs.firefox.enable = true;`:

```nix
# pin legacy path; XDG migration needs manual ~/.mozilla move on nv1
programs.firefox.configPath = ".mozilla/firefox";
```

Gate: nv1 eval clean (no warning), closure should be IDENTICAL
(stateVersion<26.05 already resolves to legacy — this just makes it
explicit). If closure moves, that's a surprise worth noting.

If Jonas prefers XDG: set `"${config.xdg.configHome}/mozilla/firefox"`
instead and file ops-* for the on-host `mv ~/.mozilla/firefox
~/.config/mozilla/firefox` step. Default to legacy-pin — lower risk,
matches feedback_original_over_copy (don't churn for upstream fashion).

## Blockers

None. Pure eval fix, no deploy needed to land.
