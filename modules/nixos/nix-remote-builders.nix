{ kin, ... }:
let
  key = kin.gen."user/nix-remote-builder-key".key;
  builder = host: user: system: {
    hostName = host; sshUser = user; sshKey = key;
    protocol = "ssh-ng"; inherit system; maxJobs = 8;
  };
in
{
  nix.distributedBuilds = true;
  nix.buildMachines = [
    (builder "mac01.numtide.com" "hetzner" "aarch64-darwin")
    (builder "mac01.numtide.com" "hetzner" "x86_64-darwin")
    (builder "bld3.numtide.com" "nix-remote-builder" "aarch64-linux")
  ];
  # Pubkey at gen/user/nix-remote-builder-key/_shared/pubkey — install on the
  # numtide builders' authorized_keys (key was regenerated; old sops one is gone).
}
