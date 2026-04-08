# Drop commented-out config referencing inputs that no longer exist

**What:** Delete commented blocks that reference flake inputs we don't
have — they can never be uncommented as-is, so they're not "disabled
config", they're noise.

- `hosts/nv1/configuration.nix:19` — `# inputs.iroh-nix.nixosModules.default`
- `hosts/nv1/configuration.nix:68-76` — `# services.iroh-nix = { … }`
  (9 lines, references `inputs.iroh-nix.packages…`)
- `modules/home/desktop/default.nix:6` —
  `# inputs.subportal.homeModules.subportal-desktop`
- `modules/home/desktop/default.nix:9-10` —
  `# services.subportal-desktop.{enable,relayUrl}`

Neither `iroh-nix` nor `subportal` exist in `flake.nix` inputs.

Also plain dead comments (no input, just cruft) in **nv1** — the only
live desktop host:
- `hosts/nv1` has none beyond iroh; `no1`/`p1` cruft dies with
  `simplify-drop-no1-p1-hosts`.

**Why:** 1d29ff0 already cleaned zerotier/tailscale on the same
principle ("maille is the only mesh"). iroh-nix and subportal are the
same shape: experiments that left a fossil. Git has the history.

**How much:** ~14 lines deleted across 2 files. Gate: nv1 evals. ~5 min.

**Blockers:** none.
