{ pkgs, inputs, ... }:
{
  imports = [ ../terminal ];

  programs.firefox.enable = true;

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
    tdesktop # telegram desktop
    termite
    vlc
    zed-editor

    # KDE stuff
    kdePackages.filelight
    kdePackages.okular

    # AI
    inputs.llm-agents.packages.${pkgs.system}.claudebox
    inputs.llm-agents.packages.${pkgs.system}.codex
    inputs.llm-agents.packages.${pkgs.system}.crush
    inputs.llm-agents.packages.${pkgs.system}.opencode
  ];
}
