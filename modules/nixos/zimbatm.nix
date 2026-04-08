{ inputs, pkgs, ... }:
{
  # uid/groups/sshKeys/password come from kin.nix users.zimbatm — this only adds
  # what kin's users service doesn't cover.
  users.users.zimbatm = {
    description = "Jonas Chevalier";
    packages = [ inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.myvim ];
    shell = "/run/current-system/sw/bin/bash";
  };
}
