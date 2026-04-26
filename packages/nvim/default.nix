{ inputs, system, ... }:
inputs.nixvim.legacyPackages.${system}.makeNixvim {
  nixpkgs.overlays = [ (import ../../overlays/vim-utils-pname-fix.nix) ];
  enableMan = false;
  editorconfig.enable = true;

  plugins = {
    airline.enable = true;
    cmp-nvim-lsp.enable = true;
    cmp-path.enable = true;
    cmp-rg.enable = true;
    cmp-treesitter.enable = true;
    direnv.enable = true;
    fugitive.enable = true;
    gitgutter.enable = true;
    nix.enable = true;
    vim-surround.enable = true;
  };
}
