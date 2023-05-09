{ pkgs, lib, ... }:
{
  # programs.firefox.package gets overwritten, which generates compile
  programs.firefox.enable = lib.mkForce false;
  home.packages = [ pkgs.firefox-wayland ];

  xdg.configFile."chromium-flags.conf" = {
    source = pkgs.writeText "chromium-flags.conf" ''
      --force-device-scale-factor=1
    '';
  };

  pam.sessionVariables = {
    # Fix JWT applications
    _JAVA_AWT_WM_NONREPARENTING = "1";
    # Fix krita and other Egl-using apps
    LD_LIBRARY_PATH = "/run/opengl-driver/lib";
  };
}
