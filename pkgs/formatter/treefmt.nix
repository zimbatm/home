{ pkgs, ... }:
{
  package = pkgs.treefmt2;

  projectRootFile = "flake.lock";

  programs.deadnix.enable = true;
  programs.nixfmt-rfc-style.enable = true;

  programs.mdformat.enable = true;

  programs.shellcheck.enable = true;
  programs.shfmt.enable = true;

  settings.formatter.deadnix.pipeline = "nix";
  settings.formatter.deadnix.priority = 1;
  settings.formatter.nixfmt-rfc-style.pipeline = "nix";
  settings.formatter.nixfmt-rfc-style.priority = 2;

  settings.formatter.shellcheck.pipeline = "shell";
  settings.formatter.shellcheck.priority = 1;
  settings.formatter.shfmt.pipeline = "shell";
  settings.formatter.shfmt.priority = 2;
}
