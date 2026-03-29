{ pkgs, ... }:
let
  inherit (pkgs) lib;
in
pkgs.rustPlatform.buildRustPackage {
  pname = "iroh-relay";
  version = "0.97.0";

  src = pkgs.fetchFromGitHub {
    owner = "n0-computer";
    repo = "iroh";
    tag = "v0.97.0";
    hash = "sha256-LHym52tDd71S8U4pX7FGexfeP4kHoUhcMzMspXH/uHQ=";
  };

  cargoHash = "sha256-xAyov/7GxQ/no/737kh+tsVlnWegnnzFeE0DdwR3K6s=";

  buildAndTestSubdir = "iroh-relay";

  # Enable the server feature to get the binary
  buildFeatures = [ "server" ];

  nativeBuildInputs = [
    pkgs.pkg-config
    pkgs.lld
  ];

  # Disable tests - they require network access
  doCheck = false;

  meta = {
    description = "Iroh relay server for NAT traversal";
    homepage = "https://github.com/n0-computer/iroh";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "iroh-relay";
  };
}
