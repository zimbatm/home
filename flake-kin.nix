{ inputs, kin }:
kin.lib.mkFleet {
  root = ./.;
  config = import ./kin.nix;
  nixpkgsConfig.allowUnfree = true;
  specialArgs = { inherit inputs; flake = inputs.self; };
}
