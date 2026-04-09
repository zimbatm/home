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
    profile = "github:zimbatm/home#homeConfigurations.zimbatm";
    uid = 1000;
    groups = [ "audio" "docker" "input" "libvirtd" "networkmanager" "video" ];
  };
  users.zimbatm-yk = { admin = true; recipientOnly = true; on = [ ]; };  # YubiKey age recipient (no unix account)
  users.migration-test = { admin = true; uid = 1001; };

  machines = {
    nv1 = { host = "fd18:cb0b:6a1d::6e42:b995:2026:deae"; tags = [ "desktop" ]; profile = "none"; };
    web2 = { host = "89.167.46.118"; tags = [ "server" ]; profile = "hetzner-cloud"; };
    relay1 = { host = "95.216.188.155"; tags = [ "server" "relay" ]; profile = "hetzner-cloud"; };
  };

  services.identity = { domain = "ztm"; on = [ "all" ]; };
  services.mesh.on = [ "all" ];
  services.mesh.relay = [ "relay1" ];
  # services.attest.on = [ "web2" ];  # needs-human: `kin gen` (zimbatm-yk
  # age-plugin-yubikey) before enabling — eval fails on web2 without
  # gen/attest/signing-key/key.age. See backlog/adopt-attest-second-builder.md.

  gen.gotosocial-restic-password = {
    for = [ "server" ];
    perMachine = false;
    script = ''head -c 32 /dev/urandom | base64 > $out/password'';
    files.password.secret = true;
  };
  gen.gotosocial-storagebox-credentials = {
    for = [ "server" ];
    perMachine = false;
    # CIFS credentials file format: "username=...\npassword=..."
    files.credentials.secret = true;
  };
}
