# kin output, kept separate so blueprint stays untouched.
# Merge into flake.nix once happy.
{ inputs, kin }:
kin.lib.mkFleet {
  root = ./.;
  config = import ./kin.nix;
  specialArgs = { inherit inputs; flake = inputs.self; };
  extraModules = [
    # Bridge: keep sops-nix module loaded so existing `sops.secrets.*` options
    # don't error during migration. sops uses the same age key kin seeds.
    inputs.sops-nix.nixosModules.default
    { sops.age.keyFile = "/var/lib/kin/key"; }
  ];
}
