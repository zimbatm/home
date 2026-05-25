{ ... }:
{
  # nixpkgs overrides applied to every host. Pure workarounds; should
  # shrink over time as upstream fixes land.
  nixpkgs.overlays = [
    (final: prev: {
      # vte 0.84.0 (in nixpkgs since 2026-05-06) fails to build —
      # `'to_integral' is not a member of 'vte'` from a C++ source
      # error upstream. termite depends on vte, srvos's mixins-terminfo
      # pulls termite.terminfo, so every server build trips on it.
      # Stub termite with a multi-output drv that emits an empty
      # terminfo dir — keeps the srvos mixin happy without compiling
      # vte. Drop this once nixpkgs ships a buildable vte again.
      termite = final.stdenv.mkDerivation {
        pname = "termite-stub";
        version = "0";
        dontUnpack = true;
        outputs = [
          "out"
          "terminfo"
        ];
        installPhase = ''
          mkdir -p $out
          mkdir -p $terminfo/share/terminfo
        '';
      };
    })
  ];
}
