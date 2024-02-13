{ config, lib, pkgs, ... }:
with lib;
let
  cfg = config.services.mycelium;

  stateDirectory = "mycelium";

  args = lib.cli.toGNUCommandLineShell { } {
    peers = cfg.peers;
    # Put the key file in the state directory
    key-file = "%S/${stateDirectory}/priv_key.bin";
    # Set a distinctive name. The default is "tun0".
    tun-name = "my0";
  };
in
{
  options = {
    services.mycelium = {
      enable = lib.mkEnableOption "Mycelium network";

      openFirewall = lib.mkEnableOption "Whether to open the ports";

      peers = lib.mkOption {
        description = "List of peers to connect to on start";
        type = lib.types.listOf lib.types.str;
        default = [
          "tcp://83.231.240.31:9651"
          "quic://185.206.122.71:9651"
        ];
      };

      package = lib.mkPackageOption pkgs "mycelium" { };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    networking.firewall.allowedTCPPorts = lib.optionals cfg.openFirewall [ 9651 ];
    networking.firewall.allowedUDPPorts = lib.optionals cfg.openFirewall [ 9650 9651 ];

    systemd.services.mycelium = {
      description = "Mycelium network";
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${lib.getExe cfg.package} ${args}";
        Restart = "always";
        RestartSec = 2;
        StateDirectory = stateDirectory;

        # TODO: Hardening
      };
    };
  };
}
