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
  users.migration-test = { admin = true; uid = 1001; };

  machines = {
    no1 = { host = "no1.zt"; tags = [ "desktop" "builder" ]; profile = "none"; };
    nv1 = { host = "nv1.zt"; tags = [ "desktop" ]; profile = "none"; };
    p1 = { host = "p1.local"; tags = [ "laptop" ]; profile = "none"; };
    web2 = { host = "89.167.46.118"; tags = [ "server" ]; profile = "hetzner-cloud"; };
  };

  services.identity = { domain = "ztm"; hosts = [ "all" ]; };
  services.mesh.member = [ "all" ];

  gen.nix-remote-builder-key = {
    for = [ "builder" ];
    perMachine = false;
    files.key.secret = true;
  };
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
