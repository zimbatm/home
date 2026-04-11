let
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOuiDoBOxgyer8vGcfAIbE6TC4n4jo8lhG9l01iJ0bZz"
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIOH4yGDIDHCOFfNeXuvYwNoSVtAPOznAHfxSTSze8tMnAAAABHNzaDo= zimbatm@p1"
  ];
in
{
  users.zimbatm = {
    admin = true;
    inherit sshKeys;
    uid = 1000;
    groups = [ "audio" "docker" "input" "libvirtd" "networkmanager" "video" ];
  };
  users.zimbatm-yk = { admin = true; recipientOnly = true; };  # YubiKey age recipient (no unix account)
  users.migration-test = { admin = true; uid = 1001; };  # still load-bearing for kin/userborn migration test (Jonas 2026-04-11)
  users.claude = {
    admin = true;
    sshKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ4A37V7FWTQgVqVNw+Ub+2AyRAgkll0ZBX6udc/C1E6 claude@kin-infra" ];
  };

  machines = {
    nv1 = { host = "fd0c:3964:8cda::6e42:b995:2026:deae"; tags = [ "desktop" ]; profile = "none"; };
    web2 = { host = "89.167.46.118"; tags = [ "server" ]; profile = "hetzner-cloud"; };
    relay1 = { host = "95.216.188.155"; tags = [ "server" "relay" ]; profile = "hetzner-cloud"; };
  };

  services.identity = { domain = "ztm"; on = [ "all" ]; };
  services.mesh.on = [ "all" ];
  services.mesh.relay = [ "relay1" ];
  services.attest.on = [ "web2" ];
}
