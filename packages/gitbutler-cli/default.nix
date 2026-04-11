{ pkgs, ... }:
pkgs.rustPlatform.buildRustPackage {
  pname = "gitbutler-cli";
  inherit (pkgs.gitbutler) version src cargoDeps cargoPatches;

  nativeBuildInputs = with pkgs; [ cmake pkg-config perl ];
  buildInputs = with pkgs; [ openssl libgit2 dbus sqlite ];

  env.OPENSSL_NO_VENDOR = "1";

  cargoBuildFlags = [ "-p" "but" ];
  cargoTestFlags = [ "-p" "but" ];
  doCheck = false;

  meta = pkgs.gitbutler.meta // {
    description = "GitButler CLI (`but`) — built from the same source as pkgs.gitbutler, which ships GUI only";
    mainProgram = "but";
  };
}
