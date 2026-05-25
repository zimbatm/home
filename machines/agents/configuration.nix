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

  users.users.zimbatm.extraGroups = [ "wheel" ];

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
  # DISPLAY=:1 is a fake to make claude-code believe a clipboard is present;
  # /etc/term-paste/xclip is the shim that returns the latest image written
  # by clip-bridge.py instead of talking to a real X server.
  programs.bash.interactiveShellInit = ''
    export DISPLAY=:1
    export PATH=/etc/term-paste:$PATH
    if [[ -z "$IN_HERDR" && ( -n "$SSH_TTY" || -n "$TTYD" ) && $- == *i* && -z "$NO_HERDR" ]]; then
      export IN_HERDR=1
      exec ${inputs.herdr.packages.${pkgs.stdenv.hostPlatform.system}.default}/bin/herdr
    fi
  '';

  # Install fake-xclip as /etc/term-paste/xclip so it shadows the real one
  # only inside the agents shells that prepend /etc/term-paste to PATH.
  environment.etc."term-paste/xclip" = {
    source = ./fake-xclip;
    mode = "0755";
  };

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
        # Diagnostic: NO_HERDR=1 bypasses the bash init herdr auto-attach so
        # we can isolate herdr from the rest of the image-paste chain.
        # Revert to `export TTYD=1` once verified.
        export NO_HERDR=1
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
        # Inject the clipboard shim into ttyd's served HTML; sub_filter
        # operates on responses so we need to forbid compression and accept
        # text/html in particular.
        sub_filter_once on;
        sub_filter_types text/html;
        sub_filter '</head>' '<script src="/clip-shim.js" defer></script></head>';
        proxy_set_header Accept-Encoding "";
      '';
    };
    locations."= /clip-shim.js" = {
      alias = "${./clip-shim.js}";
      extraConfig = ''
        types { } default_type application/javascript;
        add_header Cache-Control "no-cache";
      '';
    };
    locations."= /clip" = {
      proxyPass = "http://127.0.0.1:8090/clip";
      extraConfig = ''
        client_max_body_size 25m;
        proxy_request_buffering off;
      '';
    };
  };

  # Sidecar that receives image blobs from the browser and writes them to
  # /tmp/clip-latest.<ext>. The fake-xclip shim on PATH reads from there.
  # No real X server involved — xclip's daemonization is too fragile under
  # systemd to rely on for one-shot clipboard writes.
  systemd.services.clip-bridge = {
    description = "Browser→/tmp image paste bridge for the web terminal";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 ${./clip-bridge.py}";
      Restart = "always";
      User = "zimbatm";
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
