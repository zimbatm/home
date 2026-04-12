{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  self' = inputs.self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  # Off by default — capturing the sink monitor turns *all* desktop audio into
  # text on disk. Enable per-host only after the privacy stance in
  # backlog/needs-human/ops-live-caption-privacy.md is decided.
  options.home.live-caption.enable = lib.mkEnableOption "live-caption-log: monitor-source → NPU transcript → jsonl + sem-grep";

  config = lib.mkIf config.home.live-caption.enable {
    home.packages = [ self'.live-caption-log ];

    systemd.user.services.live-caption-log = {
      Unit = {
        Description = "System audio → NPU transcript → jsonl";
        ConditionPathExists = "/dev/accel/accel0";
        After = [
          "pipewire.service"
          "pueued.service"
        ];
      };
      Service = {
        Type = "simple";
        ExecStart = "${self'.live-caption-log}/bin/live-caption-log";
        Restart = "on-failure";
        RestartSec = "5s";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    # Nightly: fold yesterday's caption jsonl into the sem-grep corpus so
    # `sem-grep "what did the standup say about X"` works against local audio
    # history. Index is incremental on content-hash; default repo set is
    # duplicated here so the caption dir appends rather than replaces.
    systemd.user.services.live-caption-reindex = {
      Unit.Description = "sem-grep reindex with caption logs";
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "live-caption-reindex" ''
          set -eu
          state="''${XDG_STATE_HOME:-$HOME/.local/state}/live-caption"
          [ -d "$state" ] || exit 0
          export SEM_GREP_REPOS="''${SEM_GREP_REPOS:-$HOME/src/home:$HOME/src/kin:$HOME/src/iets:$HOME/src/maille:$HOME/src/meta}:$state"
          exec ${self'.sem-grep}/bin/sem-grep index
        ''}";
      };
    };
    systemd.user.timers.live-caption-reindex = {
      Unit.Description = "Nightly sem-grep reindex of caption logs";
      Timer = {
        OnCalendar = "daily";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };
  };
}
