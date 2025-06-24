{ lib, stdenv, fetchzip, autoPatchelfHook }:

stdenv.mkDerivation rec {
  pname = "opencode";
  version = "0.1.129";

  src = fetchzip {
    url = "https://github.com/sst/opencode/releases/download/v${version}/opencode-linux-x64.zip";
    sha256 = "sha256-lVvBS64TRD01qUH8Y42BWERHP8jq9mtT9SZf7sf9hHE=";
    stripRoot = false;
  };

  nativeBuildInputs = [ autoPatchelfHook ];

  dontBuild = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    
    mkdir -p $out/bin
    cp opencode $out/bin/
    chmod +x $out/bin/opencode
    
    runHook postInstall
  '';

  meta = with lib; {
    description = "AI coding agent, built for the terminal";
    homepage = "https://github.com/sst/opencode";
    license = licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "opencode";
  };
}