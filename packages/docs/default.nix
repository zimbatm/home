{
  pkgs,
  inputs,
  flake,
}:
inputs.mkdocs-numtide.lib.${pkgs.system}.mkDocs {
  name = "zimbatm-website";
  src = flake;
}
