{ pkgs, ... }:
let
  mkShare = { name, comment ? name, path ? "/data/${name}" }:
    {
      "create mask" = "0664";
      "directory mask" = "0775";
      "force group" = "users";
      "guest ok" = "no";
      "read only" = "no";
      browseable = "yes";
      comment = comment;
      path = path;
    };
in
{
  environment.systemPackages = [ pkgs.samba ];
  services.samba.enable = true;
  services.samba.securityType = "user";
  services.samba.extraConfig = ''
    hosts allow = 192.168.0.1/24 172.28.0.1/24 127.0.0.1 ::1
    map to guest = Bad Password
    server role = standalone server
    server string = silent1

    [homes]
    comment = Personal drive
    browsable = no
    writable = yes
    path = /data/homes/%S
  '';
  services.samba.shares.Movies = mkShare { name = "Movies"; };
  services.samba.shares.Music = mkShare { name = "Music"; };
  services.samba.shares.Photos = mkShare { name = "Photos"; };
  services.samba.shares."TV Shows" = mkShare { name = "TV Shows"; };

  networking.firewall.allowPing = true;
  networking.firewall.allowedTCPPorts = [ 137 138 139 445 ];
  networking.firewall.allowedUDPPorts = [ 137 138 139 ];
}
