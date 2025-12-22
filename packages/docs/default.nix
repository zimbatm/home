{
  pkgs,
  inputs,
  flake,
}:
inputs.mkdocs-numtide.lib.${pkgs.stdenv.hostPlatform.system}.mkDocs {
  name = "zimbatm-website";
  src = flake;
}
