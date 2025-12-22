{ pkgs, inputs, ... }:
{
  imports = [ ../terminal ];

  programs.firefox.enable = true;

  # ActivityWatch time tracker
  services.activitywatch = {
    enable = true;
    watchers = {
      aw-watcher-afk.package = pkgs.activitywatch;
      aw-watcher-window.package = pkgs.activitywatch;
    };
  };

  programs.ghostty = {
    enable = true;

    settings = {
      # theme = "catppuccin-mocha";
      font-size = 16;
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
    zed-editor

    # KDE stuff
    kdePackages.filelight
    kdePackages.okular

    # AI
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claudebox
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.crush
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode
  ];
}
