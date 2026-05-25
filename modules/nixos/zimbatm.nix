{ inputs, lib, pkgs, ... }:
let
  # Source of truth for zimbatm-the-human's SSH keys. The TPM key file is
  # optional — populated after `ssh-tpm-keygen` runs on nv1 the first time.
  # See docs/runbooks/ssh-tpm-agent.md.
  keysDir = ../../keys;
  readKey = name: lib.removeSuffix "\n" (builtins.readFile (keysDir + "/${name}.pub"));
  zimbatmKeys =
    [ (readKey "zimbatm-p1") ]
    ++ lib.optional (builtins.pathExists (keysDir + "/zimbatm-nv1-tpm.pub")) (readKey "zimbatm-nv1-tpm");
in
{
  users.users.zimbatm = {
    description = "Jonas Chevalier";
    isNormalUser = true;
    uid = 1000;
    group = "users";
    packages = [ inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.myvim ];
    shell = "/run/current-system/sw/bin/bash";
    openssh.authorizedKeys.keys = zimbatmKeys;
  };
  # Mirror to root so target-host=root deploys work with the same set.
  users.users.root.openssh.authorizedKeys.keys = zimbatmKeys;
}
