{ pkgs }:
pkgs.runCommand "claudebox"
  {
    buildInputs = [ pkgs.makeWrapper ];
  }
  ''
    mkdir -p $out/bin $out/share/claudebox
    
    # Install helper scripts
    cp ${./claudebox.sh} $out/bin/claudebox
    chmod +x $out/bin/claudebox
    
    # Patch shebang
    patchShebangs $out/bin/claudebox
    
    # Create claude wrapper that references the original
    makeWrapper ${pkgs.claude-code}/bin/claude $out/libexec/claudebox/claude \
      --unset DEV \
      --set CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 1 \
      --set DISABLE_AUTOUPDATER 1 \
      --set DISABLE_NON_ESSENTIAL_MODEL_CALLS 1 \
      --set DISABLE_TELEMETRY 1 \
      --set NODE_OPTIONS "--require=${./tmux-wrap.js}" \
      --inherit-argv0
    
    # Wrap claudebox start script
    wrapProgram $out/bin/claudebox \
      --prefix PATH : ${
        pkgs.lib.makeBinPath [
          pkgs.bashInteractive
          pkgs.bubblewrap
          pkgs.tmux
        ]
      } \
      --prefix PATH : $out/libexec/claudebox
  ''
