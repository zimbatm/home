{
  lib,
  writeShellScriptBin,
  winePackages,
  winetricks,
  symlinkJoin,
}:

{
  pname,
  version,
  src, # Pre-extracted derivation with Windows files
  executables, # { wrapper-name = "path/to/exe.exe"; }
  prefixName ? "wine-${pname}", # Wine prefix directory name
  winetricksVerbs ? [ ], # e.g. [ "vcrun2019" ]
  wine ? winePackages.stable, # 32-bit Wine
  meta ? { },
}:

let
  setupCommands = lib.optionalString (winetricksVerbs != [ ]) ''
    if [[ ! -f "$WINEPREFIX/.setup-done" ]]; then
      echo "First run: setting up Wine prefix at $WINEPREFIX..."
      ${lib.getExe winetricks} -q ${lib.escapeShellArgs winetricksVerbs}
      touch "$WINEPREFIX/.setup-done"
      echo "Setup complete."
    fi
  '';

  mkWrapper =
    name: exePath:
    writeShellScriptBin name ''
      set -euo pipefail
      export PATH="${wine}/bin:$PATH"
      export WINEPREFIX="''${WINEPREFIX:-''${XDG_DATA_HOME:-$HOME/.local/share}/${prefixName}}"
      ${setupCommands}
      exec wine ${src}/${exePath} "$@"
    '';

  wrappers = lib.mapAttrsToList mkWrapper executables;
in
symlinkJoin {
  name = "${pname}-${version}";
  paths = [ src ] ++ wrappers;
  inherit meta;
}
