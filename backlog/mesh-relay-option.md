# mesh: declare relay via `services.mesh.relay`, drop magic tag

## What

`kin.nix` line 21 sets `relay1 = { … tags = [ "server" "relay" ]; }` and
relies on kin's mesh service treating the literal tag `"relay"` as
special. Upstream kin (grind/schema-magic-relay-tag) replaced that
hard-coded filter with an explicit selector option:

```nix
services.mesh.relay = [ … ];  # selector: tags-or-names, like `member`
```

## Why

The `"relay"` tag is no longer load-bearing on its own — the contract
is now declared in `services.mesh`. Without this change, relay1 stops
being advertised as a relay once kin updates.

## How much

One-line addition next to `services.mesh.member`:

```nix
services.mesh.relay = [ "relay1" ];
```

(or `= [ "relay" ]` to keep selecting by the existing tag — either
works under selector semantics). The `"relay"` entry in `tags` can stay
or go; it's now purely descriptive.

## Blockers

Land after the kin change merges (`grind/schema-magic-relay-tag`).

## Falsifies

If kin pins are not bumped here, this is inert until they are.
