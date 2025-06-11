{ ... }:
{
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Disable indexing service to save power
  services.gnome.localsearch.enable = false;

  services.libinput.enable = true;
}
