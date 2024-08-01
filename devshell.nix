{ pkgs, perSystem }:
pkgs.mkShell {
  packages = [
    pkgs.nixos-anywhere
    pkgs.sbctl
    pkgs.sops
    pkgs.ssh-to-age
  ];

  # so I can run `nixos-rebuild --flake . switch` without sudo in front
  SUDO_USER = 1;
}
