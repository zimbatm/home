{ config, ... }:
{
  nix.distributedBuilds = true;
  nix.buildMachines = [
    {
      hostName = "mac01.numtide.com";
      sshUser = "hetzner";
      protocol = "ssh-ng";
      sshKey = config.sops.secrets.nix-remote-builder-key.path;
      system = "aarch64-darwin";
      maxJobs = 8;
    }
    {
      hostName = "mac01.numtide.com";
      sshUser = "hetzner";
      protocol = "ssh-ng";
      sshKey = config.sops.secrets.nix-remote-builder-key.path;
      system = "x86_64-darwin";
      maxJobs = 8;
    }
    {
      hostName = "bld3.numtide.com";
      sshUser = "nix-remote-builder";
      protocol = "ssh-ng";
      sshKey = config.sops.secrets.nix-remote-builder-key.path;
      system = "aarch64-linux";
      maxJobs = 8;
    }
  ];
  sops.secrets.nix-remote-builder-key = { };
}
