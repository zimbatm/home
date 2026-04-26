{ pkgs, ... }:
{
  # Hotfix for limine 11.4.0's legacy BIOS limlz integrity failures on
  # Hetzner Cloud. Remove once nixos-unstable carries limine >= 11.4.1.
  boot.loader.limine.package = pkgs.limine.overrideAttrs (_: rec {
    version = "11.4.1";
    src = pkgs.fetchurl {
      url = "https://github.com/Limine-Bootloader/Limine/releases/download/v${version}/limine-${version}.tar.gz";
      hash = "sha256-sTmjVVhOb2EOhohW/SMJgrM8HT5t6afq1ekv+6eZNuY=";
    };
  });
}
