{
  lib,
  stdenv,
  fetchFromGitHub,
  bun,
  makeBinaryWrapper,
}:

let
  # Create a fixed-output derivation for dependencies
  node_modules = stdenv.mkDerivation rec {
    pname = "backlog-md-node_modules";
    version = "1.0.1";

    src = fetchFromGitHub {
      owner = "MrLesk";
      repo = "Backlog.md";
      rev = "v${version}";
      hash = "sha256-SIeTvpdTNz09CMpwtn2DC1Sa4FLmvKUh0ZRIs7ZNzIk=";
    };

    impureEnvVars = lib.fetchers.proxyImpureEnvVars ++ [
      "GIT_PROXY_COMMAND"
      "SOCKS_SERVER"
    ];

    nativeBuildInputs = [ bun ];

    dontConfigure = true;

    buildPhase = ''
      runHook preBuild
      export HOME=$TMPDIR
      bun install --no-progress --frozen-lockfile
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -R ./node_modules $out
      runHook postInstall
    '';

    dontFixup = true;

    outputHash = "sha256-/04SeDeEZzRnTEIEBufg8jmYnFYbNq9EuazDJAiKPbk=";
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
  };
in
stdenv.mkDerivation rec {
  pname = "backlog-md";
  version = "1.0.1";

  src = fetchFromGitHub {
    owner = "MrLesk";
    repo = "Backlog.md";
    rev = "v${version}";
    hash = "sha256-SIeTvpdTNz09CMpwtn2DC1Sa4FLmvKUh0ZRIs7ZNzIk=";
  };

  nativeBuildInputs = [
    bun
    makeBinaryWrapper
  ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    # Link the pre-fetched node_modules
    ln -s ${node_modules}/node_modules .

    # Build the project to create the binary
    export HOME=$TMPDIR
    bun run build

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin

    # The build command creates a compiled binary
    cp dist/backlog $out/bin/backlog
    chmod +x $out/bin/backlog

    runHook postInstall
  '';

  # Don't strip the binary - bun compile embeds the JavaScript program
  # in the executable and stripping would remove it
  dontStrip = true;

  meta = {
    description = "Backlog.md - A tool for managing project collaboration between humans and AI Agents in a git ecosystem";
    homepage = "https://github.com/MrLesk/Backlog.md";
    license = lib.licenses.mit;
    maintainers = with lib.maintainers; [ ];
    mainProgram = "backlog";
    platforms = lib.platforms.all;
  };
}
