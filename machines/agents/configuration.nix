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
    inputs.disko.nixosModules.disko
    ./disko.nix
  ];

  # Hetzner Cloud cpx51 (16 vCPU AMD shared, 32 GB, 360 GB), fsn1.
  # Workstation for long-running Claude Code agent sessions. SSH in, attach
  # to tmux/dtach, run multiple agents in parallel. Not a public service —
  # only port 22 open.
  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "agents";

  # srvos hardware-hetzner-cloud sets boot.loader.grub.devices via mkDefault
  # but leaves enable off; flip it.
  boot.loader.grub.enable = true;

  # Bypass cloud-init network config — DHCPv4 + static IPv6 on the primary
  # interface. The /64 here is a placeholder; will be updated to the real
  # Hetzner-assigned one once the VM is provisioned.
  networking.useDHCP = lib.mkForce true;
  systemd.network.networks."05-enp1s0" = {
    matchConfig.Name = "enp1s0";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = false;
    };
    # TODO: replace with real /64 from `curl -H ".../v1/servers/<id>" | jq .ipv6`
    address = [ "::1/128" ];
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

  # Dev essentials. Add claude-code + llm-agents tooling once we know what
  # we want from inputs.llm-agents.packages — keep this list minimal for now.
  environment.systemPackages = with pkgs; [
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
    nodejs_22 # claude-code's wrapper is npm-distributed
  ];

  # SSH only. Nothing else is public-facing on this box.
  networking.firewall.allowedTCPPorts = [ ];

  security.sudo.wheelNeedsPassword = false;

  system.stateVersion = "26.05";
}
