{ pkgs, ... }:
{
  imports = [ ../terminal ];

  programs.firefox.enable = true;
  programs.vscode.enable = true;

  home.packages = with pkgs; [
    # Graphical
    brave
    discord
    element-desktop
    gimp
    mattermost-desktop
    signal-desktop
    slack
    tdesktop # telegram desktop
    termite
    vlc
    xournal
    zed-editor
    zoom-us

    # KDE stuff
    filelight
    krita
    okular
  ];
}
