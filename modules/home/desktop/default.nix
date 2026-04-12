{ pkgs, inputs, ... }:
let
  llm = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
  self' = inputs.self.packages.${pkgs.stdenv.hostPlatform.system};
  # nixpkgs buildGoModule puts GOPROXY in the go-modules FOD's impureEnvVars
  # (so corp proxies work). On the ant build host GOPROXY points at an authed
  # artifactory the FOD has no creds for → 401. Pin the public proxy and drop
  # GOPROXY from impureEnvVars (impure wins over explicit drv env in Nix).
  # Verified pkgs.crush@0.55.0 still hits this; upstream fix would be nixpkgs
  # buildGoModule defaulting env.GOPROXY in the FOD.
  crush =
    let
      goModules = pkgs.crush.goModules.overrideAttrs (old: {
        GOPROXY = "https://proxy.golang.org,direct";
        impureEnvVars = pkgs.lib.remove "GOPROXY" old.impureEnvVars;
      });
    in
    pkgs.crush.overrideAttrs (_: {
      inherit goModules;
    });
in
{
  imports = [
    ../terminal
    ./activitywatch.nix
  ];

  programs.firefox.enable = true;

  programs.ghostty = {
    enable = true;

    settings = {
      # theme = "catppuccin-mocha";
      font-size = 16;
    };
  };

  # Push-to-talk dictation hotkey (toggle: press to start, press to stop+type)
  dconf.settings = {
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ptt-dictate/"
      ];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/ptt-dictate" = {
      name = "Push-to-talk dictate";
      command = "ptt-dictate";
      binding = "<Super>d";
    };
  };

  home.packages = with pkgs; [
    # Graphical
    brave
    element-desktop
    joplin-desktop
    signal-desktop
    slack
    telegram-desktop

    # KDE stuff
    kdePackages.filelight
    kdePackages.okular

    # SSH shortcuts
    self'.core

    # AI
    self'.ptt-dictate
    self'.wake-listen
    self'.say-back
    self'.ask-local
    self'.llm-router
    self'.agent-eyes
    self'.gsnap
    self'.agent-meter
    self'.now-context
    self'.pty-puppet
    claude-code
    llm.claudebox
    codex
    crush
    opencode
    llm.pi
  ];

  # Always-on VAD gate on the NPU. ConditionPathExists keeps it inert until
  # the accel node is live (gated on needs-human/ops-deploy-nv1). Falsify via
  # agent-meter NPU-busy % + powertop package-W delta over a 10-min idle window.
  systemd.user.services.wake-listen = {
    Unit = {
      Description = "NPU-resident VAD gate for ptt-dictate";
      ConditionPathExists = "/dev/accel/accel0";
      After = [ "pipewire.service" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${self'.wake-listen}/bin/wake-listen";
      Restart = "on-failure";
      RestartSec = "5s";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
