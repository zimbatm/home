# feat: wire iets package into services/attest.nix

`services.attest.on = ["web2"]` is enabled and `kin gen` minted the
signing key, but `iets-attest-log` is **inactive** on web2 because
`package = null` (the systemd unit is `mkIf (cfg.package != null)`).

home has `inputs.iets`; it just isn't threaded to the service. Match
kin-infra's pattern:

1. `services/attest.nix` → wrap as `iets: { optionsType = …; eval = …
   let pkg = cfg.package or iets.packages.${pkgs.stdenv.hostPlatform.system}.iets; … }`
   and drop the `mkIf (cfg.package != null)` gate (use `pkg` directly).
2. `flake.nix:55` → `extraServices.attest = import ./services/attest.nix inputs.iets;`

Then `kin --evaluator nix deploy web2`. Probe:
`ssh root@89.167.46.118 "systemctl is-active iets-attest-log; ss -tlnp | grep 7480"`.

This is the last step to G2 threshold=2 (kin-infra hcloud-02 is
builder #1, already publishing).
