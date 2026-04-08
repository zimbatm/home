{ pkgs, inputs }:
# buildEnv (not mkShell) so .envrc can `nix build` once and PATH_add $out/bin —
# no per-cd flake re-eval.
pkgs.buildEnv {
  name = "home-devshell";
  paths = [
    inputs.kin.packages.${pkgs.stdenv.hostPlatform.system}.kin
    pkgs.age
    pkgs.age-plugin-tpm
    pkgs.hcloud
    pkgs.sbctl
    pkgs.ssh-to-age
    inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.formatter
  ];
}
