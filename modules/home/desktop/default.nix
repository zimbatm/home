{ pkgs, ... }:
{
  imports = [ ../terminal ];

  programs.firefox.enable = true;
  programs.vscode.enable = true;

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
  ];
}
