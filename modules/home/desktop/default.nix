{ pkgs, inputs, ... }:
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

    # AI
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claudebox
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.codex
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.crush
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode
  ];
}
