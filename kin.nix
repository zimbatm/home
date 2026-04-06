let
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOuiDoBOxgyer8vGcfAIbE6TC4n4jo8lhG9l01iJ0bZz"
    "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAINwWC6CJ/E6o3WGeZxbZMajC4roXnzVi8fOo1JYJSE6YAAAABHNzaDo="
  ];
in
{
  admins = [ "zimbatm" "migration-test" ];

  machines = {
    no1 = { host = "no1.zt"; tags = [ "desktop" "builder" ]; profile = "none"; };
    nv1 = { host = "nv1.zt"; tags = [ "desktop" ]; profile = "none"; };
    p1 = { host = "p1.local"; tags = [ "laptop" ]; profile = "none"; };
    docs1 = { host = "docs1.garnix"; tags = [ "server" ]; profile = "none"; };
    # relay uses system-manager (not nixosSystem) — out of scope, see flake.nix
  };

  services.identity = {
    hosts = [ "all" ];
    domain = "ztm";
    users.zimbatm = sshKeys;
  };

  services.users.zimbatm = {
    admin = true;
    inherit sshKeys;
  };

  services.wireguard.peer = [ "all" ]; # replaces zerotier + tailscale

  # External secrets (were sops; provide via `kin set`)
  gen.nix-remote-builder-key = {
    for = [ "builder" ];
    perMachine = false;
    files.key.secret = true;
  };
  gen.gotosocial-restic-password = {
    for = [ "server" ];
    perMachine = false;
    files.password.secret = true;
  };
  gen.gotosocial-storagebox-password = {
    for = [ "server" ];
    perMachine = false;
    files.password.secret = true;
  };
}
