{
  config,
  lib,
  inputs,
  pkgs,
  ...
}:
let
  cp = inputs.crops-demo.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  # Combined closure 5.7 GiB (crops-voice/selftest pull CUDA llama). Opt-in;
  # nv1 enables explicitly. Compare crops-voice wake-word vs ptt-dictate GBNF
  # path side-by-side — same mic, same Arc iGPU, two implementations.
  options.home.crops.enable = lib.mkEnableOption "crops-demo userland CLIs";

  config = lib.mkIf config.home.crops.enable {
    home.packages = [
      cp.crops-voice
      cp.crops-tts
      cp.crops-status
      cp.crops-research
      cp.crops-gpu-detect
      cp.crops-selftest
      cp.run-crops
    ];
  };
}
