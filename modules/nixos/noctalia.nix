# Noctalia Wayland desktop shell — Quickshell-based bar / launcher /
# control center for niri (and other wlr-layer-shell compositors).
#
# Ported from distro/modules/nixos/noctalia.nix (deleted upstream in
# bca67cf when the pi-chat panel was extracted out as its own
# standalone Quickshell process). The plugins-autoload patch + overlay
# from the upstream module are dropped — they only existed to wire the
# old pi-chat noctalia plugin, which no longer exists.
{ pkgs, ... }:
{
  environment.systemPackages = with pkgs; [
    noctalia-shell
    libnotify
    # Noctalia widgets shell out to these by bare name:
    #   wl-copy/wl-paste — Network/Wifi/About copy buttons, launcher
    #     calculator, "copy settings" actions
    #   xdg-open — opening URLs from About/Contributors/Supporters tabs
    wl-clipboard
    xdg-utils
  ];

  # Battery bar widget queries UPower over D-Bus; without upowerd
  # running the widget renders blank on laptops.
  services.upower.enable = true;

  systemd.user.services.noctalia-shell = {
    description = "Noctalia Wayland desktop shell";
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    restartTriggers = [ pkgs.noctalia-shell ];
    serviceConfig = {
      ExecStart = "${pkgs.noctalia-shell}/bin/noctalia-shell";
      Restart = "on-failure";
      Slice = "session.slice";
      # Noctalia spawns helpers by bare name (`sh`, `wl-paste`, ...).
      Environment = "PATH=/run/wrappers/bin:/etc/profiles/per-user/%u/bin:/run/current-system/sw/bin";
    };
  };
}
