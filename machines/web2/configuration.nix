{ inputs, config, lib, pkgs, ... }:
{
  imports = [
    inputs.self.nixosModules.common
    inputs.self.nixosModules.gotosocial
    inputs.self.nixosModules.hardening
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.srvos.nixosModules.mixins-nginx
    inputs.disko.nixosModules.disko
    inputs.agenix.nixosModules.default
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

  users.users.zimbatm = {
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOH4yGDIDHCOFfNeXuvYwNoSVtAPOznAHfxSTSze8tMnAAAABHNzaDo= zimbatm@p1"
    ];
  };
  users.users.root.openssh.authorizedKeys.keys = [
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOH4yGDIDHCOFfNeXuvYwNoSVtAPOznAHfxSTSze8tMnAAAABHNzaDo= zimbatm@p1"
  ];

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];

  # zimbatm.com static site (built from github:zimbatm/kit, data/views/zimbatm.com).
  # Was hosted on kit's "core" host; moved here so kit becomes purely a content
  # repo and web2 is the public face.
  services.nginx.virtualHosts."zimbatm.com" = {
    root = inputs.kit.packages.x86_64-linux.zimbatm-com;
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

  # Offsite backups → rsync.net via restic SFTP. Same pattern kin-infra used
  # before. SSH key + restic password live in agenix; the SSH key is a
  # placeholder until you run `agenix -e secrets/web2-restic-ssh-key.age`
  # with the rsync.net ed25519 private key body.
  age.secrets.web2-restic-password.file = ../../secrets/web2-restic-password.age;
  age.secrets.web2-restic-ssh-key = {
    file = ../../secrets/web2-restic-ssh-key.age;
    mode = "0400";
  };

  programs.ssh.knownHosts."zh6422.rsync.net".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJtclizeBy1Uo3D86HpgD3LONGVH0CJ0NT+YfZlldAJd";

  services.restic.backups =
    let
      common = service: {
        repository = "sftp:zh6422@zh6422.rsync.net:zimbatm-home-backup/${service}";
        passwordFile = config.age.secrets.web2-restic-password.path;
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
          RandomizedDelaySec = "30m";
        };
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 4"
          "--keep-monthly 6"
        ];
        extraOptions = [
          "sftp.command='ssh -i ${config.age.secrets.web2-restic-ssh-key.path} -o StrictHostKeyChecking=yes zh6422@zh6422.rsync.net -s sftp'"
        ];
        initialize = true;
      };
    in
    {
      gotosocial = common "gotosocial" // {
        paths = [ "/var/lib/gotosocial" ];
      };
    };

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

  # restic backup jails. User stays root (needs read on /var/lib/{service}),
  # but everything else clamps. ReadOnlyPaths covers what restic touches.
  systemd.services."restic-backups-gotosocial".serviceConfig = {
    NoNewPrivileges = true;
    LockPersonality = true;
    PrivateDevices = true;
    ProtectClock = true;
    ProtectControlGroups = true;
    ProtectHome = true;
    ProtectHostname = true;
    ProtectKernelLogs = true;
    ProtectKernelModules = true;
    ProtectKernelTunables = true;
    ProtectProc = "invisible";
    ProtectSystem = "strict";
    ReadOnlyPaths = [ "/var/lib/gotosocial" ];
    ReadWritePaths = [ "/var/cache/restic-backups-gotosocial" ];
    RestrictAddressFamilies = [
      "AF_INET"
      "AF_INET6"
      "AF_UNIX"
    ];
    RestrictNamespaces = true;
    RestrictRealtime = true;
    RestrictSUIDSGID = true;
    SystemCallArchitectures = "native";
    SystemCallFilter = [
      "@system-service"
      "~@privileged"
    ];
    # restic runs as root but service data dirs are mode 0700 owned by the
    # service user; root needs CAP_DAC_READ_SEARCH to traverse them.
    CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" ];
    AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" ];
    UMask = "0077";
  };
  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "26.05";
}
