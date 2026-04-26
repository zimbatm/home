# nixpkgs 0726a0ec added an `allAndOptPluginNames = map (plugin: plugin.pname) ...`
# guard in vim-utils.packDir without falling back to `name`. nixvim's
# `build.extraFiles` derivation (runCommandLocal "nvim-config") sets only
# `name`, so any wrapped neovim trips the assert. Patch the source to fall
# back to `plugin.name` — non-IFD: readFile + replaceStrings + toFile.
final: prev:
let
  pluginsDir = prev.path + "/pkgs/applications/editors/vim/plugins";
  utilsDir = pluginsDir + "/utils";
  hooksDir = pluginsDir + "/hooks";
  src = utilsDir + "/vim-utils.nix";
  # Rewrite relative-path imports/references to absolute paths so the
  # patched file works in isolation (toFile produces a flat /nix/store path).
  patched = builtins.toFile "vim-utils.nix" (
    builtins.replaceStrings
      [
        "(plugin: plugin.pname)"
        "import ./build-vim-plugin.nix"
        "../hooks/vim-gen-doc-hook.sh"
        "../hooks/vim-command-check-hook.sh"
        "../hooks/neovim-require-check-hook.sh"
      ]
      [
        "(plugin: plugin.pname or plugin.name)"
        "import ${utilsDir}/build-vim-plugin.nix"
        "${hooksDir}/vim-gen-doc-hook.sh"
        "${hooksDir}/vim-command-check-hook.sh"
        "${hooksDir}/neovim-require-check-hook.sh"
      ]
      (builtins.readFile src)
  );
in
{
  vimUtils = prev.callPackage patched { };
}
