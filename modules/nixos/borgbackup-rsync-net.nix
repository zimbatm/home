# Shared bits for the clan borgbackup → rsync.net destination. Imported only by
# hosts that are borgbackup clients (see inventory.instances.borgbackup in
# flake.nix). Each host's repo path + state folders live in its own config.
{
  config,
  lib,
  pkgs,
  ...
}:
{
  # Reuse the existing rsync.net ssh key (the same one all hosts used for
  # restic, already authorized on rsync.net) instead of minting a new one.
  # share = true: one imported copy, re-encrypted to every borgbackup client.
  # Borg's rsh (set per-destination in flake.nix) points at this file.
  clan.core.vars.generators.rsync-net-ssh = {
    share = true;
    files.value = {
      secret = true;
      mode = "0400";
    };
    prompts.value = {
      description = "rsync.net ssh private key (shared; used by borgbackup rsh)";
      type = "multiline-hidden";
      persist = true;
    };
    runtimeInputs = [ pkgs.coreutils ];
    script = ''cat "$prompts"/value > "$out"/value'';
  };

  # rsync.net exposes borg 1.4 as `borg14`; nixpkgs ships borg 1.4.x, so the
  # remote and local versions match. Without this borg can't find its server
  # binary on rsync.net. Merges into the job the clan borgbackup service defines.
  services.borgbackup.jobs.rsync-net.environment.BORG_REMOTE_PATH = "borg14";

  programs.ssh.knownHosts."zh6422.rsync.net".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJtclizeBy1Uo3D86HpgD3LONGVH0CJ0NT+YfZlldAJd";
}
