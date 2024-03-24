{ pkgs, lib, ... }:
let
  pactl = "${pkgs.pulseaudio}/bin/pactl";
in
{
  imports = [
    ../terminal
    ../desktop
    ./wayland.nix
  ];

  xdg.configFile."sway/status.toml" = {
    source = ./sway-status.toml;
    onChange = ''
      echo "TODO: Reload sway"
      #FIXME: unable to retrive socket path
      #swaymsg reload
    '';
  };

  home.packages = with pkgs; [
    brightnessctl
    #dmenu
    grim # screenshot CLI
    i3status-rust # menu bar
    lm_sensors # for i3status
    networkmanagerapplet
    pavucontrol
    playerctl
    slurp # dimension-grabbing CLI, to use with grim
    swayidle # needed by sway
    swaylock # needed by sway
    xdg-utils # needed for termite URL opening
    # xwayland
    # j4-dmenu-desktop
    bemenu

    okular

    # Add some fonts
    dejavu_fonts # just a basic good fond
    font-awesome_5 # needed by i3status-rust
    hack-font # for code

    # Screen sharing
    xdg-desktop-portal
    xdg-desktop-portal-wlr
  ];

  fonts.fontconfig.enable = true;

  services.mako.enable = true;
  services.mako.defaultTimeout = 50000;

  programs.termite = {
    enable = true;
    scrollbackLines = 10000;
    # colorsExtra = builtins.readFile
    #   "${pkgs.sources.base16-termite}/themes/base16-default-dark.config";
  };

  wayland.windowManager.sway = {
    enable = true;
    systemd.enable = true;
    wrapperFeatures = {
      gtk = true;
    };

    extraSessionCommands = ''
      export SDL_VIDEODRIVER=wayland
      # needs qt5.qtwayland in systemPackages
      export QT_QPA_PLATFORM=wayland
      export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
      # Fix for some Java AWT applications (e.g. Android Studio),
      # use this if they aren't displayed properly:
      export _JAVA_AWT_WM_NONREPARENTING=1
      # Fix krita and other Egl-using apps
      export LD_LIBRARY_PATH=/run/opengl-driver/lib
      # For xdg-desktop-portal
      export XDG_CURRENT_DESKTOP=sway
      export XDG_SESSION_TYPE=wayland
    '';

    config = {
      modifier = "Mod4";
      terminal = "termite";
      menu = ''
        $${FIXME: pkgs.j4-dmenu-desktop}/bin/j4-dmenu-desktop \
          --dmenu='BEMENU_BACKEND=wayland ${pkgs.bemenu}/bin/bemenu --ignorecase' \
          --term=termite
      '';

      keybindings = lib.mkOptionDefault {
        XF86AudioLowerVolume = "exec ${pactl} set-sink-volume $(${pactl} list sinks | head -1 | cut -d '#' -f 2) -5%";
        XF86AudioMute = "exec ${pactl} set-sink-mute $(${pactl} list sinks | head -1 | cut -d '#' -f 2) toggle";
        XF86AudioNext = "exec playerctl next";
        XF86AudioPlay = "exec playerctl play-pause";
        XF86AudioPrev = "exec playerctl previous";
        XF86AudioRaiseVolume = "exec ${pactl} set-sink-volume $(${pactl} list sinks | head -1 | cut -d '#' -f 2) +5%";
        XF86MonBrightnessDown = "exec brightnessctl set 5%-";
        XF86MonBrightnessUp = "exec brightnessctl set +5%";
        XF86LaunchB = "exec $menu";
      };

      bars = [ { statusCommand = "i3status-rs ~/.config/sway/status.toml"; } ];

      # Sway specific

      startup = [
        {
          # Start the lock screen
          # FIXME: doesn't unlock
          # command = ''
          #   swayidle \
          #     timeout 900 'swaylock -c 000000' \
          #     timeout 700 'swaymsg "output * dpms off"' \
          #     resume 'swaymsg "output * dpms on"' \
          #     before-sleep 'swaylock -c 000000'
          # '';
          command = ''
            swayidle \
              timeout 700 'swaymsg "output * dpms off"' \
              resume 'swaymsg "output * dpms on"'
          '';
        }
      ];

      input = {
        "1386:888:Wacom_Intuos_BT_M_Pen" = {
          map_to_output = "HDMI-A-2";
          # FIXME: map BTN_0 to BTN_3, BTN_STYLUS and BTN_STYLUS2 buttons
        };
      };

      output = {
        "*" = {
          bg = "~/Pictures/Wallpapers/falcon-heavy-boosters-wallpaper-2.jpg fill";
        };
        eDP-1 = {
          scale = "1.5";
        };
      };
    };

    extraConfig = ''
      #
      # Window rules
      #
      for_window [class="Slack"] {
        floating disable
      }
      assign [class="Slack"] 9
      no_focus [class="Slack"]
      for_window [app_id="firefox" title="Firefox - Sharing Indicator"] {
        kill
      }
    '';
  };

  # BETA
  # xsession.enable = true;
  # xsession.windowManager.command = "sway";

  #xdg.enable = true;
  #xdg.configFile."sway/config" = {
  #  source = ./sway-config;
  #  onChange = ''
  #    echo "Reloading sway"
  #    #FIXME: swaymsg reload
  #  '';
  #};

  # gtk.enable = true;
}
