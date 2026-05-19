{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  git,
  qt6,
  qt6Packages,
  ...
}:
stdenv.mkDerivation rec {
  pname = "lith";
  version = "1.7.58";

  src = fetchFromGitHub {
    owner = "LithApp";
    repo = "Lith";
    rev = "v${version}";
    hash = "sha256-FEo3K/wn2U2kyE3AnI4l5xalwwndG4EShkeRYrfFdwQ=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cmake
    git
    qt6.wrapQtAppsHook
  ];

  buildInputs = [
    qt6.qtbase
    qt6.qtdeclarative
    qt6.qttools
    qt6.qtwebsockets
    qt6.qtmultimedia
    qt6.qtimageformats
    qt6.qtsvg
    qt6.qtshadertools
    qt6Packages.qtkeychain
    qt6Packages.qcoro
  ];

  cmakeFlags = [
    "-DLITH_FORCE_LOCAL_PACKAGES_ONLY=ON"
  ];

  meta = {
    description = "Multiplatform mobile-focused WeeChat relay client";
    homepage = "https://lith.app";
    license = lib.licenses.gpl3Plus;
    mainProgram = "Lith";
    platforms = lib.platforms.linux;
  };
}
