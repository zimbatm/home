{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    inputs.self.nixosModules.common
    inputs.self.nixosModules.hardening
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.subportal.nixosModules.subportal
    inputs.disko.nixosModules.disko
    ./disko.nix
  ];

  # Hetzner Cloud cpx62 (16 vCPU AMD shared, 32 GB, 640 GB), fsn1.
  # Workstation for long-running Claude Code agent sessions. SSH in, attach
  # to tmux/dtach, run multiple agents in parallel. Not a public service —
  # only port 22 open.
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "agents";

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.useDHCP = lib.mkForce true;
  systemd.network.networks."05-eth" = {
    matchConfig.Name = "enp1s0 eth0";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
    };
    address = [ "2a01:4f8:c014:7e84::1/64" ];
    routes = [
      {
        Gateway = "fe80::1";
        GatewayOnLink = true;
      }
    ];
  };

  users.users.zimbatm = {
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOH4yGDIDHCOFfNeXuvYwNoSVtAPOznAHfxSTSze8tMnAAAABHNzaDo= zimbatm@p1"
    ];
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOH4yGDIDHCOFfNeXuvYwNoSVtAPOznAHfxSTSze8tMnAAAABHNzaDo= zimbatm@p1"
  ];

  # zimbatm can build via nix without sudo (trusted by the daemon).
  nix.settings.trusted-users = [ "@wheel" ];

  environment.systemPackages =
    let
      llm = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
    in
    (with pkgs; [
      git
      gh
      jujutsu
      direnv
      nix-direnv
      fish
      htop
      iotop
      tmux
      dtach
      ripgrep
      fd
      jq
      nodejs_22 # for claude-code's npm-distributed wrapper, if used outside the nix path
    ]) ++ [
      llm.claude-code
      llm.happy-coder # `happy` — mobile/web client (app.happy.engineering),
                      # E2E-encrypted, sessions still run locally on agents.
    ];

  # SSH login auto-attaches to a tmux session named "main" so disconnects
  # don't kill running agents. Interactive + TTY-only; safe for scp / git.
  # Image-paste over SSH+tmux doesn't work today (tmux intercepts OSC 52,
  # and SSH doesn't forward clipboard) — see backlog for a browser-terminal
  # alternative built on libghostty/ghostty-web.
  programs.bash.interactiveShellInit = ''
    if [[ -z "$TMUX" && -n "$SSH_TTY" && $- == *i* ]]; then
      exec ${pkgs.tmux}/bin/tmux new-session -A -s main
    fi
  '';

  programs.tmux = {
    enable = true;
    terminal = "tmux-256color";
    extraConfig = ''
      set -g allow-passthrough on
      set -g set-clipboard on
      set -ga terminal-features ",*:RGB"
      set -ga terminal-features ",*:hyperlinks"
      set -ga terminal-features ",*:clipboard"
      set -g mouse on
    '';
  };

  # SSH only. Nothing else is public-facing on this box.
  networking.firewall.allowedTCPPorts = [ ];

  # subportal: agent-side forwarder for xdg-open / notify-send / file
  # transfer to nv1 over iroh p2p. Enroll once with:
  #   ssh root@agents.ztm.io subportal ticket | subportal-desktop enroll
  programs.subportal.enable = true;
  programs.subportal.agent.enable = true;
  # systemd user manager needs to stick around across SSH disconnects.
  systemd.tmpfiles.rules = [
    "f /var/lib/systemd/linger/root 0644 root root - -"
  ];
  # Iroh needs AF_NETLINK for netmon (interface watching).
  systemd.user.services.subportal-agent.serviceConfig.RestrictAddressFamilies = [
    "AF_INET"
    "AF_INET6"
    "AF_UNIX"
    "AF_NETLINK"
  ];

  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "26.05";
}
