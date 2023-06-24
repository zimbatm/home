# Common configuration accross *all* the machines
{ inputs, ... }:
{
  imports = [
    inputs.srvos.nixosModules.common
    inputs.srvos.nixosModules.mixins-terminfo
    inputs.home-manager.nixosModules.default
    ./zimbatm.nix
  ];

  # Configure Let's Encrypt
  security.acme.acceptTerms = true;
  security.acme.defaults.email = "admin+acme@numtide.com";

  # Configure all the machines with NumTide's binary cache
  nix.settings.trusted-public-keys = [
    "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
    "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
  ];
  nix.settings.substituters = [
    "https://cache.garnix.io"
    "https://numtide.cachix.org"
  ];

  nixpkgs.config.allowUnfree = true;

  # One network to rule them all.
  services.zerotierone.enable = true;
  services.zerotierone.joinNetworks = [ "565799d8f6567eae" ];
  networking.extraHosts = ''
    172.28.61.193  no1.zt
    172.28.80.106  x1.zt
  '';

  # Configure home-manager
  home-manager.extraSpecialArgs.inputs = inputs; # forward the inputs
  home-manager.useGlobalPkgs = true; # don't create another instance of nixpkgs
  home-manager.useUserPackages = true; # install user packages directly to the user's profile
}
