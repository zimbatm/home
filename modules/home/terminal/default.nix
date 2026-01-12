{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
{
  imports = [ inputs.nix-index-database.homeModules.nix-index ];
  # also wrap and install comma
  programs.nix-index-database.comma.enable = true;

  home.file.".inputrc".text = builtins.readFile ./inputrc;
  home.packages = with pkgs; [
    # TUI
    tmate

    # CLI stuff
    bc
    dnsutils
    fd
    file
    gh
    gnupg
    gopass
    h
    jq
    jujutsu
    mdsh
    psmisc
    pueue
    pwgen
    ripgrep
    ruby
    shellcheck
    shfmt
    tea
    tree
    watchexec
    wget
    wl-clipboard

    # Linux man pages!
    man-pages

    # Coding
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.myvim
    inputs.self.packages.${pkgs.stdenv.hostPlatform.system}.nvim
    go
    gopls
    (lib.lowPrio gotools)

    # Nix stuff
    nix-update
    nixd
    nixfmt
    nixpkgs-review

    # Git stuff
    git-absorb
    git-extras
    git-gone
  ];

  pam.sessionVariables = {
    EDITOR = "vim";
  };

  programs.bash = {
    enable = true;

    initExtra = ''
      # Eg: start your session with zsh and run bash, you'll have the wrong SHELL
      if [[ $(basename "$SHELL") != bash ]]; then
        SHELL=bash
      fi

      if [[ "zimbatm" = $(id -u -n) ]]; then
        # Remove \u
        PS1=$(echo "$PS1" | sed 's|\\u||g')
      fi

      has() {
        type -P "$1" &>/dev/null
      }

      where() {
        readlink -f "$(type -P "$1")"
      }

      alias top=ytop
      alias ssh='TERM=xterm ssh'
      alias drun='docker run -ti --rm'
      alias screenshot='grim -g "$(slurp)" - | wl-copy'

      # don't install shell extensions in the nix shell
      if [[ -n $IN_NIX_SHELL ]]; then return; fi

      has h && eval "$(command h --setup "$HOME/go/src")"
      has up && eval "$(command up --setup)"
    '';

    profileExtra = ''
      export PATH=$HOME/go/bin:$PATH
      export GOPATH=$HOME/go

      # Don't check for mail
      unset MAILCHECK

      export EDITOR=vim
    '';
  };

  programs.direnv = {
    enable = true;
    config = {
      disable_stdin = true;
      strict_env = true;
      #warn_timeout = 30;
    };
    stdlib = builtins.readFile ./direnvrc;
  };

  programs.fzf.enable = true;

  programs.mergiraf.enable = true;

  programs.git = {
    enable = true;
    ignores = [
      # direnv
      ".direnv"
      ".envrc"

      # nix
      "result"
      "result-*"

      # vim
      ".*.swp"

      # VSCode
      ".vscode"

      # Claude Code
      ".claude"
      "CLAUDE.local.md"

      # Work notes
      "WORK.md"
    ];
    #lfs.enable = true;
    settings = {
      user = {
        name = "zimbatm";
        email = "zimbatm@zimbatm.com";
      };
      alias = {
        amend = "commit --amend";
        clean = "!git gone -f | xargs -r git branch -d";
        co = "checkout";
        # Rebase the current work to the origin default branch. Typically add
        # `-i` to it so it becomes interactive.
        rb = "rebase origin/HEAD";
        review = "diff --cached";
        st = "status -sb";
        # Fix the remote head for `git rb` to work.
        update-head = "remote set-head origin --auto";
      };
      branch = {
        autosetuprebase = "always";
        mergeoptions = "--no-ff";
        sort = "-committerdate";
      };
      column.ui = "auto";
      commit.verbose = true;
      core.whitespace = "trailing-space,space-before-tab,tab-in-indent";
      diff = {
        algorithm = "histogram";
        colorMoved = "plain";
        mnemonicPrefix = true;
        renames = true;
      };
      fetch = {
        all = true;
        prune = true;
        pruneTags = true;
        parallel = 10;
      };
      help.autoCorrect = "prompt";
      init.defaultBranch = "main";
      merge.conflictstyle = "zdiff3";
      push = {
        autoSetupRemote = true;
        default = "simple";
        followTags = true;
      };
      pull.rebase = true;
      rebase = {
        autoSquash = true;
        autoStash = true;
        updateRefs = true;
      };
      rerere = {
        autoUpdate = true;
        enabled = true;
      };
      tag.sort = "version:refname";
      # gpg.format = "ssh";
      submodule.recurse = true;
      url."ssh://git@github.com/".pushInsteadOf = "https://github.com/";
    };
  };

  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 1800;
    pinentry.package = pkgs.pinentry-gnome3;
  };

  programs.htop.enable = true;

  programs.keychain.enable = true;

  programs.rofi.enable = true;

  programs.starship = {
    enable = true;
    settings = {
      git_status.disabled = true;
      character.success_symbol = "[\\$](bold green)";
      character.error_symbol = "[\\$](bold red)";
      character.vicmd_symbol = "[❮](bold green)";
    };
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        compression = true;
        serverAliveInterval = 60;
        controlMaster = "auto";
        controlPersist = "10m";
        controlPath = "~/.ssh/control-%C";
        extraOptions = {
          # Breaks deploy_nixos
          #IdentitiesOnly = "yes";
          StrictHostKeyChecking = "no";
        };
      };
      "github.com" = {
        user = "git";
        identityFile = "~/.ssh/id_ed25519_sk";
        identitiesOnly = true;
      };
    };
  };

  programs.tmux.enable = true;

  programs.gh-dash = {
    enable = true;

    settings = {
      prSections = [
        {
          title = "Nixpkgs";
          filters = "is:open -is:draft -author:@me repo:NixOS/nixpkgs";
        }
        {
          title = "ninit";
          filters = "is:open -is:draft -author:@me repo:NixOS/nixpkgs init at";
        }
        {
          title = "minit";
          filters = "is:merged -is:draft -author:@me repo:NixOS/nixpkgs init at";
        }
        {
          title = "Nixpkgs (pings)";
          filters = "is:open -is:draft involves:@me -author:@me repo:NixOS/nixpkgs";
        }
        {
          title = "My Pull Requests";
          filters = "is:open author:@me";
        }
        {
          title = "Needs My Review";
          filters = "is:open review-requested:@me";
        }
        {
          title = "Involved";
          filters = "is:open involves:@me -author:@me";
        }
      ];

      issuesSections = [
        {
          title = "nixpkgs";
          filters = "is:open repo:NixOS/nixpkgs";
        }
        {
          title = "My Issues";
          filters = "is:open author:@me";
        }
        {
          title = "Assigned";
          filters = "is:open assignee:@me";
        }
        {
          title = "Involved";
          filters = "is:open involves:@me -author:@me";
        }
      ];

      repoPaths = {
        "NixOS/nixpkgs" = "~/go/src/github.com/NixOS/nixpkgs";
      };

      pager = {
        diff = "delta";
      };
    };
  };

  xresources.properties = {
    # Sensible defaults
    "XTerm*locale" = false;
    "XTerm*utf8" = true;
    "XTerm*scrollTtyOutput" = false;
    "XTerm*scrollKey" = true;
    "XTerm*bellIsUrgent" = true;
    "XTerm*metaSendsEscape" = true;
    # Styling
    "XTerm*faceName" = "DejaVu Sans Mono";
    "XTerm*boldMode" = false;
    "XTerm*faceSize" = 11;
    "XTerm*Background" = "black";
    "XTerm*Foreground" = "white";
    # "XTerm.vt100.internalBorder" = 16;
    "XTerm.borderWidth" = 0;
    # XTerm libsixel configuration
    "XTerm*decTerminalID" = "vt340";
    "XTerm*numColorRegisters" = 256;
  };
}
