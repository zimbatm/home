{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  # Import an existing secret into clan vars (sops). The value is brought over
  # from agenix via `clan vars set <machine> <gen>/value` (NOT regenerated);
  # sops-nix deploys it to /run/secrets/vars/<gen>/value. `extraFile` carries
  # owner/group/mode/restartUnits where a consumer needs them.
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
    inputs.self.nixosModules.bluesky-pds
    inputs.self.nixosModules.common
    inputs.self.nixosModules.agent-deploy
    inputs.self.nixosModules.gotosocial
    inputs.self.nixosModules.hardening
    inputs.self.nixosModules.hc-ping
    inputs.self.nixosModules.pocket-id-clients
    inputs.self.nixosModules.tinc-ztm
    inputs.self.nixosModules.borgbackup-rsync-net
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.srvos.nixosModules.mixins-nginx
    inputs.disko.nixosModules.disko
    ./disko.nix
  ];

  # Hetzner Cloud cx23, hel1, BIOS GRUB. Hosts the gts.zimbatm.com (GoToSocial)
  # service and the zimbatm.com static site.
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "web2";

  # srvos hardware-hetzner-cloud sets boot.loader.grub.devices via mkDefault
  # but leaves enable off; flip it.
  boot.loader.grub.enable = true;

  # And forces useDHCP=false expecting cloud-init network config — bypass
  # with straight DHCP on the primary interface, then bind the static IPv6.
  networking.useDHCP = lib.mkForce true;
  systemd.network.networks."05-enp1s0" = {
    matchConfig.Name = "enp1s0";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
    };
    address = [ "2a01:4f9:c014:fac3::1/64" ];
    routes = [
      {
        Gateway = "fe80::1";
        GatewayOnLink = true;
      }
    ];
  };

  # Hetzner Cloud Volume web2-gts (scsi-0HC_Volume_105754691) holds the
  # gotosocial sqlite + media. nofail so a missing volume can't block boot.
  fileSystems."/var/lib/gotosocial" = {
    device = "/dev/disk/by-id/scsi-0HC_Volume_105754691";
    fsType = "ext4";
    options = [
      "x-systemd.device-timeout=30s"
      "nofail"
    ];
  };

  users.users.zimbatm.extraGroups = [ "wheel" ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # zimbatm.com static site (built from github:zimbatm/kit, data/views/zimbatm.com).
  # Was hosted on kit's "core" host; moved here so kit becomes purely a content
  # repo and web2 is the public face.
  services.nginx.virtualHosts."zimbatm.com" = {
    root = inputs.self.packages.x86_64-linux.zimbatm-com;
    enableACME = true;
    forceSSL = true;
    locations."/".tryFiles = "$uri $uri/ =404";
    # Nostr NIP-05 identity verification needs CORS.
    locations."/.well-known/nostr.json".extraConfig = ''
      add_header Access-Control-Allow-Origin "*";
    '';
  };
  services.nginx.virtualHosts."www.zimbatm.com" = {
    enableACME = true;
    forceSSL = true;
    globalRedirect = "zimbatm.com";
  };

  # ─── Pocket ID — passkey OIDC IdP at id.zimbatm.com ─────────────────────
  # SSO root for everything internal. Lives here (the zimbatm.com host)
  # per [[feedback-identity-host-separation]] — id.zimbatm.com is a
  # zimbatm-identity surface so it belongs on web2. Was on the now-retired
  # mail VM before #82.
  # Migrated agenix -> clan vars. pocket-id-static-api-key is shared with agents
  # (web2 serves Pocket ID; agents reconciles its OIDC client), so share = true.
  clan.core.vars.generators.pocket-id-encryption-key = mkImport {
    description = "Pocket ID ENCRYPTION_KEY (web2)";
  };
  clan.core.vars.generators.pocket-id-static-api-key = mkImport {
    description = "Pocket ID STATIC_API_KEY (shared web2 + agents)";
    share = true;
  };

  services.pocket-id = {
    enable = true;
    credentials = {
      ENCRYPTION_KEY = config.clan.core.vars.generators.pocket-id-encryption-key.files.value.path;
      STATIC_API_KEY = config.clan.core.vars.generators.pocket-id-static-api-key.files.value.path;
    };
    settings = {
      APP_URL = "https://id.zimbatm.com";
      TRUST_PROXY = true;
      # `::` is Go's dual-stack listen — accepts both 127.0.0.1 and ::1.
      # glibc's getaddrinfo returns IPv6 first for "localhost"; binding
      # only 127.0.0.1 led to intermittent ECONNREFUSED from nginx
      # (see [[reference_nginx_proxy_localhost_vs_ip]] companion gotcha).
      HOST = "::";
      PORT = 1411;
      ANALYTICS_DISABLED = true;
    };
  };

  # Reconcile OIDC clients into Pocket ID via its API. Individual clients
  # are declared next to the services they front (e.g. agents-ttyd lives
  # in machines/agents/configuration.nix).
  services.pocketIdClients = {
    apiBaseUrl = "https://id.zimbatm.com/api";
    apiKeyFile = config.clan.core.vars.generators.pocket-id-static-api-key.files.value.path;
  };

  services.nginx.virtualHosts."id.zimbatm.com" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      # `localhost` not `127.0.0.1` — see
      # [[reference_nginx_proxy_localhost_vs_ip]].
      proxyPass = "http://localhost:1411";
      extraConfig = ''
        # Pocket ID's response headers (long CSP) overflow nginx's
        # default 4k buffer.
        proxy_buffer_size 256k;
        proxy_buffers 4 512k;
        proxy_busy_buffers_size 512k;
      '';
    };
  };

  # Offsite backups → rsync.net via clan borgbackup (replaces the old
  # services.restic.backups). The union of clan.core.state.*.folders below
  # becomes one borg archive; destination + shared key live in flake.nix
  # (inventory.instances.borgbackup) + the borgbackup-rsync-net module.
  clan.core.state.gotosocial.folders = [ "/var/lib/gotosocial" ];
  clan.core.state.pocket-id.folders = [ "/var/lib/pocket-id" ];
  clan.core.state.bluesky-pds.folders = [ "/var/lib/pds" ];

  clan.core.vars.generators.hc-ping-gotosocial = mkImport {
    description = "healthchecks.io ping URL for the borg backup (web2)";
  };
  services.hcPing.units."borgbackup-job-rsync-net".secret =
    config.clan.core.vars.generators.hc-ping-gotosocial.files.value.path;

  # ---------------------------------------------------------------------------
  # Per-service systemd sandbox overrides. nixpkgs ships these with minimal
  # hardening; the common Protect* / Restrict* set drops the blast radius if
  # any one of these gets popped.
  # ---------------------------------------------------------------------------

  # gotosocial: nixpkgs sets ProtectSystem=full + a couple Protect*. Tighten
  # to ProtectSystem=strict with an explicit ReadWritePath, plus the rest of
  # the standard set.
  systemd.services.gotosocial.serviceConfig = {
    ProtectSystem = lib.mkForce "strict";
    ReadWritePaths = [ "/var/lib/gotosocial" ];
    ProtectClock = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectProc = "invisible";
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
    SystemCallFilter = [
      "@system-service"
      "~@privileged"
    ];
    CapabilityBoundingSet = "";
    UMask = "0077";
  };

  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "26.05";
}
