{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  # Import an existing secret into clan vars (sops): value carried over from
  # agenix via `clan vars set <machine> <gen>/value` (NOT regenerated); sops-nix
  # deploys it to /run/secrets/vars/<gen>/value. `share = true` stores one copy
  # re-encrypted to every consuming machine; `extraFile` carries
  # owner/group/mode/restartUnits.
  mkImport =
    {
      description,
      share ? false,
      extraFile ? { },
    }:
    {
      inherit share;
      files.value = {
        secret = true;
      }
      // extraFile;
      prompts.value = {
        inherit description;
        type = "hidden";
        persist = true;
      };
      runtimeInputs = [ pkgs.coreutils ];
      script = ''cat "$prompts"/value > "$out"/value'';
    };
in
{
  imports = [
    inputs.self.nixosModules.common
    inputs.self.nixosModules.agent-deploy
    inputs.self.nixosModules.hardening
    inputs.self.nixosModules.borgbackup-rsync-net
    inputs.self.nixosModules.pocket-id-clients
    inputs.self.nixosModules.tinc-ztm
    # Remote-pi executor: WebSocket daemon embedding pi (one in-process
    # session per chat) plus the served pi-web PWA. See services.pi-sessiond.
    inputs.spaces.nixosModules.pi-sessiond
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

  # Phone (Termux) key — agents-only, so it doesn't ride along to every host
  # via modules/nixos/zimbatm.nix. Lets zimbatm SSH in from the phone to
  # attach to long-running agent sessions.
  users.users.zimbatm.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII+nIj43n4afAhW0SYBrTrus/4W9LnqKXVWFQbduj2wc u0_a272@localhost"
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
    ])
    ++ [
      llm.claude-code
    ];

  # SSH login (or ttyd-spawned bash) auto-attaches to a tmux session
  # named `main`. tmux persists across detach, so a ttyd reconnect (after
  # an oauth2-proxy auth refresh, browser tab close, etc.) reattaches to
  # the same panes instead of starting a fresh bash. Detach: Ctrl-b d.
  # Opt out: `NO_TMUX=1 ssh agents.ztm.io`.
  # DISPLAY=:1 is a fake to make claude-code believe a clipboard is present;
  # /etc/term-paste/xclip is the shim that returns the latest image written
  # by clip-bridge.py instead of talking to a real X server.
  programs.bash.interactiveShellInit = ''
    export DISPLAY=:1
    export PATH=/etc/term-paste:$PATH
    if [[ -z "$TMUX" && ( -n "$SSH_TTY" || -n "$TTYD" ) && $- == *i* && -z "$NO_TMUX" ]]; then
      exec ${pkgs.tmux}/bin/tmux new-session -A -s main
    fi
  '';

  # System tmux config (read by the bare `tmux` the shell init exec's into).
  # Name each window after the current directory's basename, so windows track
  # the folder you cd into.
  environment.etc."tmux.conf".text = ''
    set -g automatic-rename on
    set -g automatic-rename-format '#{b:pane_current_path}'
  '';

  # Install fake-xclip as /etc/term-paste/xclip so it shadows the real one
  # only inside the agents shells that prepend /etc/term-paste to PATH.
  environment.etc."term-paste/xclip" = {
    source = ./fake-xclip;
    mode = "0755";
  };

  # SSH + nginx (LE-terminated web terminal at 443, ACME HTTP-01 on 80).
  # Previously mTLS-gated with our own term CA; now SSO via Pocket ID
  # through oauth2-proxy. No per-device cert provisioning, single login.
  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # pi-sessiond's WebSocket port stays off the public interface (no entry in
  # allowedTCPPorts above; openFirewall left false). nginx reaches it on
  # loopback for the SSO-gated PWA; nv1's panel reaches it over the tinc mesh,
  # so the port is opened only on the tinc-ztm interface.
  networking.firewall.interfaces."tinc-ztm".allowedTCPPorts = [ 8770 ];

  # Remote-pi executor. Headless Hetzner box has no GPU, so inference goes to
  # OpenRouter rather than a local llama-swap; the daemon registers OpenRouter's
  # catalog and new sessions default to it. Token + API key are systemd
  # credentials (LoadCredential), never copied into the store.
  # Shared with nv1 (pi-chat backend + executor client). Migrated agenix -> vars.
  clan.core.vars.generators.openrouter-api-key = mkImport {
    description = "OpenRouter API key (shared nv1 + agents)";
    share = true;
    extraFile.restartUnits = [ "pi-sessiond.service" ];
  };
  clan.core.vars.generators.pi-sessiond-token = mkImport {
    description = "pi-sessiond hello token (shared nv1 + agents)";
    share = true;
    # nginx serves this token to oauth2-proxy-authenticated PWA clients (the
    # agent.ztm.io /pi-web-token location) so the browser auto-connects without
    # a manual paste. Make it group-readable by nginx (already in `keys`);
    # pi-sessiond still reads it as root via LoadCredential.
    extraFile = {
      group = "keys";
      mode = "0440";
      restartUnits = [ "pi-sessiond.service" ];
    };
  };
  services.pi-sessiond = {
    enable = true;
    # Bind all interfaces; the firewall (loopback always open + tinc-ztm rule
    # above) is what scopes reachability, and the `hello` token gates the WS.
    host = "0.0.0.0";
    port = 8770;
    tokenFile = config.clan.core.vars.generators.pi-sessiond-token.files.value.path;
    serveWebUi = true;
    defaultProvider = "openrouter";
    defaultModel = "anthropic/claude-sonnet-4.5";
    openrouter = {
      enable = true;
      apiKeyFile = config.clan.core.vars.generators.openrouter-api-key.files.value.path;
    };
  };
  # pi-sessiond loads its token + OpenRouter key via systemd LoadCredential at
  # unit-start. sops-nix installs vars during activation (before multi-user),
  # and restartUnits (set on the token/key files) bounces the unit when a
  # secret changes — so the old agenix-install-secrets ordering is no longer
  # needed.

  # pocket-id-static-api-key shared with web2 (which serves Pocket ID).
  clan.core.vars.generators.pocket-id-static-api-key = mkImport {
    description = "Pocket ID STATIC_API_KEY (shared web2 + agents)";
    share = true;
  };
  clan.core.vars.generators.oauth2-proxy-agents-cookie = mkImport {
    description = "oauth2-proxy cookie secret (agents)";
  };
  # nginx needs to traverse /run/agenix/ (root:keys, 0750) to reach secret files.
  users.users.nginx.extraGroups = [ "keys" ];

  # Register the OIDC client in Pocket ID (mail.zimbatm.com). The reconciler
  # runs locally here, talks to id.zimbatm.com via the API key, and writes
  # /run/pocket-id-clients/agents-ttyd/{id,secret} for oauth2-proxy to read.
  services.pocketIdClients = {
    apiBaseUrl = "https://id.zimbatm.com/api";
    apiKeyFile = config.clan.core.vars.generators.pocket-id-static-api-key.files.value.path;
    clients.agents-ttyd = {
      name = "agents.ztm.io terminal";
      callbackURLs = [ "https://agents.ztm.io/oauth2/callback" ];
      pkceEnabled = true;
    };
  };

  # oauth2-proxy: nginx auth_request → here → Pocket ID OIDC.
  services.oauth2-proxy = {
    enable = true;
    provider = "oidc";
    oidcIssuerUrl = "https://id.zimbatm.com";
    # client_id is also the slug we used in pocketIdClients; client_secret
    # is the one the reconciler generated and stored at /run/pocket-id-clients/.
    clientID = "agents-ttyd";
    clientSecretFile = "/run/pocket-id-clients/agents-ttyd/secret";
    cookie.secretFile = config.clan.core.vars.generators.oauth2-proxy-agents-cookie.files.value.path;
    cookie.domain = ".ztm.io"; # share session across future *.ztm.io SSO targets
    cookie.refresh = "1h";
    redirectURL = "https://agents.ztm.io/oauth2/callback";
    email.domains = [ "*" ];
    reverseProxy = true;
    setXauthrequest = true;
    extraConfig = {
      "skip-provider-button" = true; # single-IdP setup, skip the chooser
      "whitelist-domain" = ".ztm.io";
      # Pocket ID's client config has pkceEnabled = true, so the token
      # exchange fails with "Invalid code verifier" unless oauth2-proxy
      # actually sends the PKCE challenge. S256 is the modern method.
      "code-challenge-method" = "S256";
    };
    nginx.domain = "agents.ztm.io";
    # Both the terminal (agents.ztm.io) and the pi-web PWA (agent.ztm.io)
    # sit behind the same oauth2-proxy. The OIDC callback always lands on
    # agents.ztm.io (the pinned redirectURL); the shared `.ztm.io` cookie +
    # `whitelist-domain` then carry the session back to agent.ztm.io, so no
    # second Pocket ID client/callback is needed.
    nginx.virtualHosts = {
      "agents.ztm.io" = { };
      "agent.ztm.io" = { };
    };
  };
  # oauth2-proxy starts before pocket-id-clients has run; depend on it so
  # the client_secret file exists when oauth2-proxy reads it.
  systemd.services.oauth2-proxy = {
    after = [ "pocket-id-clients.service" ];
    requires = [ "pocket-id-clients.service" ];
    serviceConfig.SupplementaryGroups = [ "pocket-id-clients" ];
  };

  # ttyd: PTY-over-WebSocket on loopback; nginx terminates TLS + Pocket ID
  # SSO before proxying. Runs as zimbatm so the shell isn't root. The
  # entrypoint sets TTYD=1 so interactiveShellInit's tmux auto-attach
  # fires (the usual trigger is SSH_TTY, which ttyd doesn't set).
  # Image-paste end-to-end relies on xterm.js's ImageAddon parsing iTerm2
  # OSC 1337 in the browser.
  services.ttyd = {
    enable = true;
    user = "zimbatm";
    interface = "127.0.0.1";
    port = 7681;
    writeable = true; # (sic — option name has a typo upstream)
    entrypoint = [
      (toString (
        pkgs.writeShellScript "ttyd-shell" ''
          export TTYD=1
          exec ${pkgs.bash}/bin/bash -l
        ''
      ))
    ];
    clientOptions = {
      fontSize = "16";
      fontFamily = "monospace";
    };
  };

  services.nginx.virtualHosts."agents.ztm.io" = {
    enableACME = true;
    forceSSL = true;
    # services.oauth2-proxy.nginx.virtualHosts attaches `auth_request
    # /oauth2/auth` + the /oauth2/* locations to this vhost. The
    # locations below sit BEHIND that gate; oauth2-proxy lets the
    # request through only after the user has a valid Pocket ID
    # session.
    locations."/" = {
      proxyPass = "http://127.0.0.1:7681";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_read_timeout 1d;
        proxy_send_timeout 1d;
        # Inject the clipboard shim into ttyd's served HTML; sub_filter
        # operates on responses so forbid compression for text/html.
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

  # pi-web PWA + pi-sessiond WebSocket, same origin. oauth2-proxy gates HTTP
  # access (see services.oauth2-proxy.nginx.virtualHosts above); the daemon's
  # `hello` token gates the WS on top. A single "/" location serves the PWA
  # assets, GET /executors, and the ws:// upgrade — proxyWebsockets wires the
  # Upgrade/Connection headers and is a no-op for the plain HTTP requests.
  #
  # Token auto-inject: the PWA otherwise asks the user to paste the executor
  # token once. Since oauth2-proxy already authenticated them, sub_filter
  # injects a bootstrap into the served HTML that fetches the token from the
  # SSO-gated /pi-web-token endpoint and clicks Connect — same trust boundary
  # (any Pocket ID user who can load the PWA can already use the executor).
  # Mirrors the ttyd clip-shim sub_filter pattern on the agents.ztm.io vhost.
  services.nginx.virtualHosts."agent.ztm.io" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:8770";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_read_timeout 1d;
        proxy_send_timeout 1d;
        # sub_filter needs uncompressed HTML; only rewrites text/html, so the
        # JS/JSON assets and the ws:// upgrade pass through untouched.
        proxy_set_header Accept-Encoding "";
        sub_filter_once on;
        sub_filter_types text/html;
        sub_filter '</body>' '<script>(function(){function s(t){t=(t||"").trim();if(!t)return;try{localStorage.setItem("pi-web.token",t)}catch(e){}var n=0,iv=setInterval(function(){var g=document.getElementById("gate"),c=document.getElementById("connect"),i=document.getElementById("token");if(g&&g.style.display==="none"){clearInterval(iv);return}if(c&&i){i.value=t;c.click()}if(++n>50)clearInterval(iv)},100)}fetch("/pi-web-token",{cache:"no-store"}).then(function(r){return r.ok?r.text():Promise.reject()}).then(s).catch(function(){})})();</script></body>';
      '';
    };
    # The executor token, served only to oauth2-proxy-authenticated clients:
    # this location inherits the server-level `auth_request /oauth2/auth`.
    locations."= /pi-web-token" = {
      alias = config.clan.core.vars.generators.pi-sessiond-token.files.value.path;
      extraConfig = ''
        default_type text/plain;
        add_header Cache-Control "no-store";
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

  # Offsite backups → rsync.net via clan borgbackup (replaces restic). Targets
  # /home/zimbatm where every long-running Claude Code conversation, tmux
  # scrollback, and scratch git tree lives — a VM-die wipes them otherwise.
  # Cache/build excludes are set on the borgbackup client in flake.nix;
  # destination + shared key live in flake.nix + the borgbackup-rsync-net module.
  clan.core.state.home.folders = [ "/home/zimbatm" ];

  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "26.05";
}
