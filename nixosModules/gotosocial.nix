{ config, ... }:
let
  domain = "gts.zimbatm.com";
  cfg = config.services.gotosocial;
in
{
  # Some secrets we will need below
  sops.secrets.gotosocial-restic-password = { };
  sops.secrets.gotosocial-storagebox-password = { };

  # Configure gotosocial
  services.gotosocial = {
    enable = true;
    settings.account-domain = "zimbatm.com";
    settings.accounts-allow-custom-css = true;
    settings.accounts-registration-open = false;
    settings.host = domain;
    settings.instance-expose-public-timeline = true;
  };

  # Put nginx in front
  services.nginx.virtualHosts."${domain}" = {
    enableACME = true;
    forceSSL = true;

    # Redirect / to my user since it's a single user install
    locations."= /" = {
      return = "302 $scheme://$host/@zimbatm";
    };

    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString cfg.settings.port}";
      proxyWebsockets = true;
    };
  };

  # Bind the Hetzner storage box to the host for the backups
  boot.supportedFilesystems = [ "cifs" ];
  fileSystems."/mnt/gotosocial-backup" = {
    device = "//u351392.your-storagebox.de/backup";
    fsType = "cifs";
    options = [
      "credentials=${config.sops.secrets.gotosocial-storagebox-password.path}"
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

  # Backup to the storage box
  services.restic.backups."gotosocial" = {
    initialize = true;
    passwordFile = config.sops.secrets.gotosocial-restic-password.path;
    paths = [ "/var/lib/gotosocial" ];
    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 5"
      "--keep-monthly 6"
    ];
    repository = "/mnt/gotosocial-backup/gotosocial";
    timerConfig.OnCalendar = "hourly";
  };
}
