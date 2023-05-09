{ inputs, ... }:
{
  imports = [
    ./common.nix
    inputs.srvos.nixosModules.server
  ];
}
