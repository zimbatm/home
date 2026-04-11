{ inputs, ... }:
{
  nix.registry.nixpkgs.to = { type = "path"; path = toString inputs.nixpkgs; };
}
