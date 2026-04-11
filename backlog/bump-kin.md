# bump-kin: 43cfb97→e173e39 for hostcert IPv6 principal fix

**What:** `nix flake update kin` (currently 43cfb97, revCount 1497).
Upstream HEAD e173e39 has +7 commits, two functional for home.

**Why** (not age — kin is 0d stale — but unblocks drift):

- **8179a78 / da68650** `identity/machine: add RFC 5952 canonical IPv6
  to host-cert principals` — fixes the bug filed from here
  (`../kin/backlog/bug-hostcert-ipv6-principal.md` @ 2d918a1). nv1's
  host cert currently lists only the compressed `::` form; ssh
  canonicalizes to `:0:` → `kin status nv1` fails host-key verification.
  After bump + `kin gen` regenerates the cert with both forms, drift
  probing works without workarounds. Directly unblocks
  `backlog/needs-human/ops-deploy-nv1.md` structural section.
- **3c6470c / e173e39** `bug-proxyjump-unguarded: tighten type to
  hostType∪@ + reject self-ref` — hardens the `machines.<n>.proxyJump`
  option home uses for nv1. No behavior change here (our value `relay1`
  is valid), but picks up the type guard.

**How much:** ~0.1r. `nix flake update kin`, then `kin gen` (expect
`gen/ssh/nv1/host-cert.pub` or equivalent to change — verify principals
list both `fd0c:3964:8cda::6e42:b995:2026:deae` and
`fd0c:3964:8cda:0:6e42:b995:2026:deae`). Gate: 3/3 eval+dry-build +
`kin gen --check`.

**Blockers:** none. Bumper priority says nixpkgs > kin, but nixpkgs is
2d fresh and this bump has a specific functional payoff.
