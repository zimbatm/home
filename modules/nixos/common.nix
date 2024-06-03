# Common configuration accross *all* the machines
{ inputs, lib, ... }:
{
  imports = [
    ./zimbatm.nix
    inputs.home-manager.nixosModules.default
    inputs.srvos.nixosModules.common
    inputs.srvos.nixosModules.mixins-terminfo
  ];

  # Configure Let's Encrypt
  security.acme.acceptTerms = true;
  security.acme.defaults.email = "zimbatm@zimbatm.com";

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

  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [ "zerotierone" ];

  # One network to rule them all.
  services.zerotierone.enable = true;
  services.zerotierone.joinNetworks = [ "565799d8f6567eae" ];
  networking.extraHosts = ''
    172.28.61.193  no1.zt
  '';

  networking.firewall.allowPing = true;

  # Configure home-manager
  home-manager.extraSpecialArgs.inputs = inputs; # forward the inputs
  home-manager.useGlobalPkgs = true; # don't create another instance of nixpkgs
  home-manager.useUserPackages = true; # install user packages directly to the user's profile
}
