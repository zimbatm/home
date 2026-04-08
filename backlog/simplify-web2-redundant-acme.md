# web2: drop redundant `security.acme` — already in common.nix

**What:** Delete `hosts/web2/configuration.nix:8`:
```nix
security.acme = { acceptTerms = true; defaults.email = "zimbatm@zimbatm.com"; };
```

**Why:** `modules/nixos/common.nix:14-15` sets the identical values.
web2 gets common via the kin `hetzner-cloud` profile (same path relay1
uses — relay1 has no acme line and evals fine). Per-host duplication of
fleet-wide config is exactly what common.nix exists to prevent.

**How much:** Delete 1 line. Gate: `nix eval
.#nixosConfigurations.web2.config.security.acme.defaults.email` still
returns `zimbatm@zimbatm.com`. ~2 min.

**Blockers:** none — but if web2 *doesn't* actually pull common.nix
(verify the eval first), that's a separate bug: it'd mean web2 is
missing the substituters/home-manager/userborn config too.
