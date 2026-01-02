{ pkgs, inputs, ... }:
{
  # ActivityWatch time tracker
  services.activitywatch = {
    enable = true;
    watchers = {
      aw-watcher-afk = {
        package = pkgs.aw-watcher-afk;
        settings = {
          poll_time = 2;
          timeout = 300;
        };
      };

      aw-watcher-window-wayland = {
        package = pkgs.aw-watcher-window-wayland;
        settings = {
          poll_time = 1;
        };
      };
    };
  };

  systemd.user.services.activitywatch-watcher-aw-watcher-afk = {
    Unit = {
      After = [
        "graphical-session-pre.target"
        "aw-server.service"
      ];
      PartOf = [ "graphical-session.target" ];
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };

  systemd.user.services.activitywatch-watcher-aw-watcher-window-wayland = {
    Unit = {
      After = [
        "graphical-session-pre.target"
        "aw-server.service"
      ];
      PartOf = [ "graphical-session.target" ];
    };

    Install.WantedBy = [ "graphical-session.target" ];
  };
}
