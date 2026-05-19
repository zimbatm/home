{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  # weechat-matrix (poljar/weechat-matrix 0.3.0 in nixpkgs) still depends on
  # `future`, which is marked unsupported for python>=3.13. Pin the entire
  # weechat stack to python3.12 so the scripts build and load.
  py = pkgs.python312Packages;

  weechatUnwrapped = pkgs.weechat-unwrapped.override {
    python3Packages = py;
  };

  weechatScripts = pkgs.weechatScripts.override {
    python3Packages = py;
  };

  wrapWeechat = pkgs.wrapWeechat.override {
    python3Packages = py;
  };

  weechat = wrapWeechat weechatUnwrapped {
    configure =
      { availablePlugins, ... }:
      {
        plugins = [
          availablePlugins.python
          availablePlugins.perl
        ];
        scripts = with weechatScripts; [
          wee-slack
          weechat-matrix
        ];
      };
  };
in
{
  imports = [
    inputs.self.nixosModules.common
    inputs.srvos.nixosModules.server
    inputs.srvos.nixosModules.hardware-hetzner-cloud
    inputs.disko.nixosModules.disko
    inputs.subportal.nixosModules.subportal
    ./disko.nix
  ];

  # Hetzner Cloud cx23 (Intel x86, 2c/4GB/40GB, BIOS), fsn1.
  # Long-running weechat-headless under systemd; clients (Lith, Glowing Bear,
  # Weechat-Android, another weechat) connect via the relay protocol.
  nixpkgs.hostPlatform = "x86_64-linux";
  # matrix-nio[olm] -> olm-3.2.16; olm is deprecated (replaced by vodozemac)
  # and marked insecure in nixpkgs. Standard signoff for personal use.
  nixpkgs.config.permittedInsecurePackages = [ "olm-3.2.16" ];

  networking.hostName = "chat";

  # srvos hetzner-cloud sets boot.loader.grub.devices via mkDefault but leaves
  # the master enable off, so the bootloader never gets installed. Flip it.
  boot.loader.grub.enable = true;

  # srvos hetzner-cloud disables DHCP, expecting cloud-init to write static
  # config from a metadata source. That only works if the datasource is
  # reachable, which it isn't until *some* network is up. Let networkd just
  # DHCP on the primary interface — Hetzner Cloud's DHCP is fine for this.
  networking.useDHCP = lib.mkForce true;

  services.weechat = {
    enable = true;
    headless = true;
    package = weechat;
  };

  # Same wrapped weechat in PATH so `sudo -u weechat weechat …` works for
  # interactive setup (stopping the service + running the TUI).
  environment.systemPackages = [ weechat ];

  # subportal server-side: provides xdg-open / notify-send drop-ins that
  # forward to enrolled desktops (nv1) over iroh p2p. Enroll once with:
  #   ssh root@chat subportal ticket | subportal-desktop enroll
  programs.subportal.enable = true;
  programs.subportal.agent.enable = true;
  # subportal-agent is a systemd USER service. On a headless server the user
  # manager only runs at login unless we enable lingering — pin it for root
  # so the agent stays up across SSH disconnects and reboots.
  systemd.tmpfiles.rules = [
    "f /var/lib/systemd/linger/root 0644 root root - -"
  ];

  # zimbatm can read/edit the weechat state dir for first-time relay setup
  # (`sudo systemctl stop weechat && weechat-headless --dir /var/lib/weechat`
  # to attach via a one-shot session, then `/relay add ...; /save; /quit`).
  users.users.zimbatm.extraGroups = [
    "wheel"
    "weechat"
  ];

  users.users.zimbatm.openssh.authorizedKeys.keys = [
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOH4yGDIDHCOFfNeXuvYwNoSVtAPOznAHfxSTSze8tMnAAAABHNzaDo= zimbatm@p1"
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOH4yGDIDHCOFfNeXuvYwNoSVtAPOznAHfxSTSze8tMnAAAABHNzaDo= zimbatm@p1"
  ];

  # Relay port. Plain TCP for now; switch to TLS (port 9443) once chat has a
  # DNS name + ACME cert.
  networking.firewall.allowedTCPPorts = [ 9001 ];

  # Local Matrix homeserver + bridges (synapse + mautrix-signal + mautrix-
  # telegram) were here previously. Removed for now — using @jonas:numtide.com
  # as a remote HS via weechat-matrix. Agenix scaffolding is kept (cheap) so
  # the bridges can come back later without re-bootstrapping.

  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "26.05";
}
