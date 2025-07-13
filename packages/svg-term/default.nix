{ pkgs, ... }:
let
  version = "2.1.1";
in
pkgs.stdenv.mkDerivation rec {
  pname = "svg-term-cli";
  inherit version;

  src = pkgs.fetchFromGitHub {
    owner = "marionebl";
    repo = "svg-term-cli";
    rev = "v${version}";
    hash = "sha256-sB4/SM48UmqaYKj6kzfjzITroL0l/QL4Gg5GSrQ+pdk=";
  };

  offlineCache = pkgs.fetchYarnDeps {
    yarnLock = "${src}/yarn.lock";
    hash = "sha256-4Q1NP3VhnACcrZ1XUFPtgSlk1Eh8Kp02rOgijoRJFcI=";
  };

  nativeBuildInputs = with pkgs; [
    yarnConfigHook
    yarnBuildHook
    nodejs
    makeWrapper
  ];

  # Build TypeScript code
  buildPhase = ''
    runHook preBuild

    export HOME=$(mktemp -d)
    yarn config --offline set yarn-offline-mirror ${offlineCache}
    fixup-yarn-lock yarn.lock
    yarn install --offline --frozen-lockfile --ignore-scripts
    yarn build

    runHook postBuild
  '';

  # Install the built CLI tool
  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib $out/bin

    # Copy the built files and dependencies
    cp -r lib $out/
    cp -r node_modules $out/
    cp package.json $out/

    # Create wrapper script
    makeWrapper ${pkgs.nodejs}/bin/node $out/bin/svg-term \
      --add-flags $out/lib/cli.js \
      --set NODE_PATH $out/node_modules

    runHook postInstall
  '';

  meta = with pkgs.lib; {
    description = "Share terminal sessions via SVG animations";
    homepage = "https://github.com/marionebl/svg-term-cli";
    license = licenses.mit;
    mainProgram = "svg-term";
  };
}
