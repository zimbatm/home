{ pkgs, inputs, ... }:
let
  llm = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
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
    pkgs.crush.overrideAttrs (_: { inherit goModules; });
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
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.core

    # AI
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.ptt-dictate
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.say-back
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.ask-local
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.llm-router
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.agent-eyes
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.gsnap
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.agent-meter
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.now-context
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.pty-puppet
    claude-code
    llm.claudebox
    codex
    crush
    opencode
    llm.pi
  ];
}
