{ pkgs, ... }:
with pkgs;
vim_configurable.customize {
  name = "vim";
  # store plugins in a vim package
  vimrcConfig.packages.myPackage = {
    # plugins to load on start
    start = with vimPlugins; [
      ### Completion ###
      # Asynchronous Lint Engine
      ale

      # Fuzzy Find completion. RipGrep. Both go together
      fzf-vim
      fzfWrapper

      ### Motions ###

      # More text objects.
      targets-vim
      vim-surround
      # motion: gc
      vim-commentary
      vim-repeat

      ### Git ###
      vim-fugitive
      vim-gitgutter
      # Hub for fugitive
      vim-rhubarb

      ### Syntax ###
      syntastic
      vim-polyglot

      vim-orgmode
      #vim-go
      #rust-vim
      vim-docbk
      vim-docbk-snippets

      ### Writing ###

      # goyo
      # neuron-vim

      ### Misc ###

      # Per project configuration
      editorconfig-vim
      vimproc
      # :Rename, :SudoWrite
      vim-eunuch

      ### UI & colors ###
      # base16-vim
      vim-airline
      vim-airline-themes
    ];
    # manually loadable by calling `:packadd $plugin-name`
    #opt = [ phpCompletion elm-vim ];
    # To automatically load a plugin when opening a filetype, add vimrc lines like:
    # autocmd FileType php :packadd phpCompletion
  };
  vimrcConfig.customRC = builtins.readFile ./vimrc;
}
