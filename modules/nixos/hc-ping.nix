{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.hcPing;
in
{
  options.services.hcPing.units = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule {
        options.secret = lib.mkOption {
          type = lib.types.path;
          description = "Path to a file (e.g. agenix-decrypted) containing the healthchecks.io UUID.";
        };
      }
    );
    default = { };
    description = ''
      Map of `<systemd unit name>` to its HC ping config. Attaches an
      ExecStopPost that pings `https://hc-ping.com/<uuid>` on success or
      `…/<uuid>/fail` otherwise, based on `$SERVICE_RESULT`.
    '';
  };

  # Use `postStop` (script body, lines-type → merges via concatenation) instead
  # of serviceConfig.ExecStopPost — the restic NixOS module already sets its
  # own postStop, and these compose cleanly. $SERVICE_RESULT is set by systemd.
  config.systemd.services = lib.mapAttrs (_: unitCfg: {
    postStop = ''
      _hc_uuid=$(cat ${unitCfg.secret})
      _hc_sfx=""
      [ "''${SERVICE_RESULT:-}" = success ] || _hc_sfx="/fail"
      ${pkgs.curl}/bin/curl -fsS --retry 3 -m 10 "https://hc-ping.com/$_hc_uuid$_hc_sfx" >/dev/null || true
    '';
  }) cfg.units;
}
