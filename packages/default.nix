{ self, inputs, ... }:
{
  perSystem =
    { system, pkgs, ... }:
    {
      packages = {
        # The most important package in this repo
        default = pkgs.alpacasay;

        # re-export our packages
        inherit (pkgs) alpacasay myvim;
      };
      # make pkgs available to all `perSystem` functions
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        config = {
          allowUnfree = true;
        };
        overlays = [ self.overlays.default ];
      };
    };

  flake.overlays.default = _final: prev: {
    alpacasay = prev.callPackage ./alpacasay { };
    myvim = prev.callPackage ./myvim { };
  };
}
