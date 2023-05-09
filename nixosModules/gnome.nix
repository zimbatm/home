{ ... }:
{
  services.xserver = {
    enable = true;
    layout = "us";
    libinput.enable = true;

    desktopManager.gnome.enable = true;
    displayManager.gdm.enable = true;
  };
}
