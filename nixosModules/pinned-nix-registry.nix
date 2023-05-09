{ inputs, lib, ... }:
{
  # Override the registry for all the inputs that we're using. That avoids
  # annoying issues where nixpkgs gets TTL-ed.
  nix.registry = lib.mapAttrs
    (_name: value: {
      to = {
        type = "path";
        path = toString value;
      };
    })
    inputs;
}
