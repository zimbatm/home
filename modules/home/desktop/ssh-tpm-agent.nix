{ config, lib, pkgs, ... }:
{
  # ssh-tpm-agent: silent SSH signing backed by nv1's TPM 2.0 chip.
  # Replaces the SSH_ASKPASS coercion dance the YubiKey-SK path needs for
  # deploys from this workstation.
  #
  # Does NOT take over the global SSH_AUTH_SOCK — that's owned by
  # `rich-ssh-agent` (modules/home/terminal/), which provides
  # context-rich confirms for sudo/pam_rssh and other YubiKey-touched
  # operations. To use this agent for a deploy, prefix the command:
  #
  #     tpm nixos-rebuild switch --flake .#agents --target-host ...
  #
  # or:
  #
  #     SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-tpm-agent.sock ssh root@…
  #
  # Membership in the `tss` group (set in machines/nv1/configuration.nix
  # extraGroups) is required to access /dev/tpmrm0.
  home.packages = [ pkgs.ssh-tpm-agent ];

  systemd.user.services.ssh-tpm-agent = {
    Unit = {
      Description = "SSH agent backed by TPM 2.0";
      Documentation = [ "https://github.com/Foxboron/ssh-tpm-agent" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${pkgs.ssh-tpm-agent}/bin/ssh-tpm-agent --listener %t/ssh-tpm-agent.sock";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "default.target" ];
  };

  programs.bash.shellAliases.tpm = "SSH_AUTH_SOCK=$XDG_RUNTIME_DIR/ssh-tpm-agent.sock";
}
