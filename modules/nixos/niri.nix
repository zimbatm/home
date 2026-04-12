# Niri scrollable-tiling compositor as a second GDM session.
#
# GNOME stays primary; this just adds a "Niri" entry to the GDM gear
# menu. nixpkgs-only — no extra flake input. config.kdl structure
# cribbed from crops-demo at authoring time, stripped of crops-user
# paths / messaging-daemon / noctalia-shell / greetd auto-login.
{ pkgs, ... }:
{
  programs.niri.enable = true;

  environment.systemPackages = with pkgs; [
    foot # terminal
    fuzzel # launcher
    waybar # status bar (v1: stock config)
    wl-clipboard
    brightnessctl
    playerctl
  ];

  # System-wide default; per-user ~/.config/niri/config.kdl overrides.
  environment.etc."xdg/niri/config.kdl".text = ''
    input {
      keyboard {
        xkb { layout "us"; }
        numlock
      }
      touchpad {
        tap
        natural-scroll
      }
      focus-follows-mouse max-scroll-amount="0%"
    }

    layout {
      gaps 8
      center-focused-column "on-overflow"
      preset-column-widths {
        proportion 0.33333
        proportion 0.5
        proportion 0.66667
      }
      default-column-width { proportion 0.5; }
      focus-ring {
        width 3
        active-color "#7fc8ff"
        inactive-color "#505050"
      }
      border { off; }
    }

    prefer-no-csd
    screenshot-path "~/Pictures/Screenshots/screenshot-%Y-%m-%d-%H-%M-%S.png"

    window-rule {
      geometry-corner-radius 8
      clip-to-geometry true
    }

    spawn-at-startup "waybar"

    binds {
      Mod+Shift+Slash { show-hotkey-overlay; }

      // Launch
      Mod+Return { spawn "foot"; }
      Mod+T      { spawn "foot"; }
      Mod+D      { spawn "fuzzel"; }

      // Overview
      Mod+O repeat=false { toggle-overview; }

      // Windows
      Mod+Q repeat=false { close-window; }
      Mod+Left  { focus-column-left; }
      Mod+Down  { focus-window-down; }
      Mod+Up    { focus-window-up; }
      Mod+Right { focus-column-right; }
      Mod+H     { focus-column-left; }
      Mod+J     { focus-window-down; }
      Mod+K     { focus-window-up; }
      Mod+L     { focus-column-right; }

      Mod+Ctrl+Left  { move-column-left; }
      Mod+Ctrl+Down  { move-window-down; }
      Mod+Ctrl+Up    { move-window-up; }
      Mod+Ctrl+Right { move-column-right; }
      Mod+Ctrl+H     { move-column-left; }
      Mod+Ctrl+J     { move-window-down; }
      Mod+Ctrl+K     { move-window-up; }
      Mod+Ctrl+L     { move-column-right; }

      Mod+Shift+Left  { focus-monitor-left; }
      Mod+Shift+Right { focus-monitor-right; }

      // Sizing
      Mod+R { switch-preset-column-width; }
      Mod+F { maximize-column; }
      Mod+Shift+F { fullscreen-window; }
      Mod+C { center-column; }
      Mod+Minus { set-column-width "-10%"; }
      Mod+Equal { set-column-width "+10%"; }

      // Float / tabs / consume
      Mod+V       { toggle-window-floating; }
      Mod+Shift+V { switch-focus-between-floating-and-tiling; }
      Mod+W       { toggle-column-tabbed-display; }
      Mod+BracketLeft  { consume-or-expel-window-left; }
      Mod+BracketRight { consume-or-expel-window-right; }

      // Workspaces
      Mod+1 { focus-workspace 1; }
      Mod+2 { focus-workspace 2; }
      Mod+3 { focus-workspace 3; }
      Mod+4 { focus-workspace 4; }
      Mod+5 { focus-workspace 5; }
      Mod+Ctrl+1 { move-column-to-workspace 1; }
      Mod+Ctrl+2 { move-column-to-workspace 2; }
      Mod+Ctrl+3 { move-column-to-workspace 3; }
      Mod+Ctrl+4 { move-column-to-workspace 4; }
      Mod+Ctrl+5 { move-column-to-workspace 5; }
      Mod+Page_Down { focus-workspace-down; }
      Mod+Page_Up   { focus-workspace-up; }

      // Media keys
      XF86AudioRaiseVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%+"; }
      XF86AudioLowerVolume allow-when-locked=true { spawn "wpctl" "set-volume" "@DEFAULT_AUDIO_SINK@" "5%-"; }
      XF86AudioMute        allow-when-locked=true { spawn "wpctl" "set-mute" "@DEFAULT_AUDIO_SINK@" "toggle"; }
      XF86AudioPlay allow-when-locked=true { spawn "playerctl" "play-pause"; }
      XF86AudioPrev allow-when-locked=true { spawn "playerctl" "previous"; }
      XF86AudioNext allow-when-locked=true { spawn "playerctl" "next"; }
      XF86MonBrightnessUp   { spawn "brightnessctl" "set" "+10%"; }
      XF86MonBrightnessDown { spawn "brightnessctl" "set" "10%-"; }

      // Screenshot (niri built-in)
      Print       { screenshot; }
      Shift+Print { screenshot-screen; }
      Alt+Print   { screenshot-window; }

      // Session
      Mod+Shift+E { quit; }
      Ctrl+Alt+Delete { quit; }
    }
  '';
}
