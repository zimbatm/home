{ pkgs, ... }:
{
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;

  # Disable indexing service to save power
  services.gnome.localsearch.enable = false;

  services.gnome.gcr-ssh-agent.enable = true;

  programs.ssh.askPassword = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";
  programs.ssh.enableAskPassword = true;

  services.libinput.enable = true;
}
