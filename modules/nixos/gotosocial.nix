{ config, kin, ... }:
let
  domain = "gts.zimbatm.com";
  cfg = config.services.gotosocial;
in
{
  services.gotosocial = {
    enable = true;
    # Forward from the apex: /.well-known/{nodeinfo,host-meta,webfinger}
    settings.account-domain = "zimbatm.com";
    settings.accounts-allow-custom-css = true;
    settings.accounts-registration-open = false;
    settings.host = domain;
    settings.instance-expose-public-timeline = true;
  };

  services.nginx.virtualHosts."${domain}" = {
    enableACME = true;
    forceSSL = true;
    locations."= /".return = "302 $scheme://$host/@zimbatm";
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString cfg.settings.port}";
      proxyWebsockets = true;
    };
  };

  # Hetzner storage box for restic repo (credentials via kin gen, CIFS format)
  boot.supportedFilesystems = [ "cifs" ];
  fileSystems."/mnt/gotosocial-backup" = {
    device = "//u351392.your-storagebox.de/backup";
    fsType = "cifs";
    options = [
      "credentials=${kin.gen."user/gotosocial-storagebox-credentials".credentials}"
      "nofail"
      "_netdev"
      "x-systemd.automount"
      "vers=3"
      "rsize=65536"
      "wsize=130048"
      "iocharset=utf8"
      "cache=loose"
    ];
  };

  services.restic.backups.gotosocial = {
    initialize = true;
    passwordFile = kin.gen."user/gotosocial-restic-password".password;
    paths = [ "/var/lib/gotosocial" ];
    pruneOpts = [ "--keep-daily 5" "--keep-weekly 1" "--keep-monthly 1" ];
    repository = "/mnt/gotosocial-backup/gotosocial";
    timerConfig.OnCalendar = "hourly";
  };
}
