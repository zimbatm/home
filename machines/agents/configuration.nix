{
  inputs,
  config,
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
    inputs.srvos.nixosModules.mixins-nginx
    inputs.subportal.nixosModules.subportal
    inputs.nix-index-database.nixosModules.nix-index
    inputs.disko.nixosModules.disko
    inputs.agenix.nixosModules.default
    ./disko.nix
  ];

  programs.nix-index-database.comma.enable = true;

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

  # SSH login (or ttyd-spawned bash) auto-attaches to a herdr session.
  # herdr is a tmux-shaped multiplexer purpose-built for AI coding agents
  # — knows per-pane working/blocked/done state, persists across detach.
  # Detach: Ctrl-b q. Opt out: `NO_HERDR=1 ssh agents.ztm.io`.
  programs.bash.interactiveShellInit = ''
    if [[ -z "$IN_HERDR" && ( -n "$SSH_TTY" || -n "$TTYD" ) && $- == *i* && -z "$NO_HERDR" ]]; then
      export IN_HERDR=1
      exec ${inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/herdr
    fi
  '';

  # SSH + nginx (mTLS web terminal on 443). No public CA: the term CA at
  # pki/term-ca.crt signs both the server cert and client certs, so the
  # browser that already trusts that CA (one-time import alongside the .p12)
  # also trusts the server. No ACME, no port 80.
  networking.firewall.allowedTCPPorts = [ 443 ];

  age.secrets."agents.ztm.io-server-key" = {
    file = ../../secrets/agents.ztm.io-server-key.age;
    owner = "nginx";
    group = "nginx";
    mode = "0400";
  };
  # nginx needs to traverse /run/agenix/ (root:keys, 0750) to reach the key.
  users.users.nginx.extraGroups = [ "keys" ];

  # ttyd: PTY-over-WebSocket on loopback; nginx terminates TLS and enforces
  # client-cert (mTLS) before proxying. Runs as zimbatm so the shell isn't
  # root; entrypoint sets TTYD=1 so interactiveShellInit's herdr auto-attach
  # fires (the usual trigger is SSH_TTY, which ttyd doesn't set).
  # Image-paste end-to-end relies on xterm.js's ImageAddon parsing iTerm2
  # OSC 1337 in the browser.
  services.ttyd = {
    enable = true;
    user = "zimbatm";
    interface = "127.0.0.1";
    port = 7681;
    writeable = true;  # (sic — option name has a typo upstream)
    entrypoint = [
      (toString (pkgs.writeShellScript "ttyd-shell" ''
        export TTYD=1
        exec ${pkgs.bash}/bin/bash -l
      ''))
    ];
    clientOptions = {
      fontSize = "16";
      fontFamily = "monospace";
    };
  };

  services.nginx.virtualHosts."agents.ztm.io" = {
    onlySSL = true;
    sslCertificate = ../../pki/agents.ztm.io.crt;
    sslCertificateKey = config.age.secrets."agents.ztm.io-server-key".path;
    extraConfig = ''
      ssl_client_certificate ${../../pki/term-ca.crt};
      ssl_verify_client on;
      ssl_verify_depth 1;
    '';
    locations."/" = {
      proxyPass = "http://127.0.0.1:7681";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_read_timeout 1d;
        proxy_send_timeout 1d;
        proxy_set_header X-Forwarded-Client-Verify $ssl_client_verify;
        proxy_set_header X-Forwarded-Client-DN     $ssl_client_s_dn;
      '';
    };
  };

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
