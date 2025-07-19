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
    inputs.nix-ai-tools.packages.${pkgs.system}.backlog-md
    inputs.nix-ai-tools.packages.${pkgs.system}.claudebox
    inputs.nix-ai-tools.packages.${pkgs.system}.gemini-cli
    inputs.nix-ai-tools.packages.${pkgs.system}.opencode
  ];
}
