{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let
  # 10.42.0.0/24 is the private backplane between our hosts. /24 leaves
  # headroom for laptop / phone roamers later. Host IDs are stable per
  # node so dns-by-static-host (e.g. /etc/hosts injection) is cheap.
  nodeMap = {
    nv1 = "10.42.0.10";
    chat = "10.42.0.11";
    web2 = "10.42.0.12";
    mail = "10.42.0.13";
    mc1 = "10.42.0.14";
    agents = "10.42.0.15";
  };

  nodeName = config.networking.hostName;
  nodeIP = nodeMap.${nodeName};

  hostsDir = ../../tinc/hosts;
  hostFiles = lib.mapAttrs (name: _: builtins.readFile (hostsDir + "/${name}")) nodeMap;

  # ConnectTo: chat + web2 are the always-on bootstrap peers. Filter
  # self so a node doesn't try to dial itself. Tinc routes any-to-any
  # once two nodes meet; this list only seeds the graph.
  bootstrap = lib.filter (n: n != nodeName) [
    "chat"
    "web2"
  ];
in
{
  imports = [ inputs.tincr.nixosModules.tincr ];

  # Per-host private key, agenix-encrypted to zimbatm + the host's own
  # recipient. Generated out-of-band; see docs/runbooks/tinc-ztm.md.
  age.secrets."tinc-ztm-${nodeName}-key" = {
    file = ../../secrets + "/tinc-ztm-${nodeName}-key.age";
    owner = "tincr";
    group = "tincr";
    mode = "0400";
  };

  services.tincr.networks.ztm = {
    nodeName = nodeName;
    ed25519PrivateKeyFile = config.age.secrets."tinc-ztm-${nodeName}-key".path;
    hosts = hostFiles;
    connectTo = bootstrap;
    openFirewall = true;
    # Eager startup so each host actively dials its ConnectTo peers at
    # boot. With socketActivation (the module default) tincd only fires
    # on incoming meta connections — the mesh never forms.
    socketActivation = false;
  };

  # tinc creates the TUN device; networkd adds our IP so the kernel
  # routes 10.42.0.0/24 over it. ConfigureWithoutCarrier so it doesn't
  # wait for a link signal (tinc-ztm is point-to-point virtual).
  systemd.network.networks."40-tinc-ztm" = {
    matchConfig.Name = "tinc-ztm";
    networkConfig.ConfigureWithoutCarrier = true;
    address = [ "${nodeIP}/24" ];
  };

  # /etc/hosts entries so internal services can bind/refer to
  # `<peer>.ztm` regardless of public DNS. Cheap and avoids a DNS
  # round-trip.
  networking.hosts = lib.mapAttrs' (n: ip: lib.nameValuePair ip [ "${n}.ztm" ]) nodeMap;
}
