{ pkgs, ... }:
let
  inherit (pkgs) lib stdenvNoCC p7zip;

  mkWineApp = pkgs.callPackage ../../lib/mkWineApp.nix { };

  version = "516.1669";

  byond-unwrapped = stdenvNoCC.mkDerivation {
    pname = "byond-unwrapped";
    inherit version;
    # Installer is kept in repo because byond.com has Cloudflare protection
    # that blocks automated downloads (fetchurl fails)
    src = ./byond_516.1669.exe;
    nativeBuildInputs = [ p7zip ];
    dontUnpack = true;
    buildPhase = ''
      runHook preBuild
      7z x -y $src
      runHook postBuild
    '';
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r bin cfg help $out/
      runHook postInstall
    '';
  };
in
mkWineApp {
  pname = "byond";
  inherit version;
  src = byond-unwrapped;
  winetricksVerbs = [ "vcrun2019" ];
  executables = {
    byond = "bin/byond.exe";
    dreammaker = "bin/dreammaker.exe";
    dreamseeker = "bin/dreamseeker.exe";
    dreamdaemon = "bin/dreamdaemon.exe";
    dm = "bin/dm.exe";
    dd = "bin/dd.exe";
  };
  meta = {
    description = "BYOND - multiplayer game creation platform";
    homepage = "https://www.byond.com/";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" ];
    mainProgram = "byond";
  };
}
