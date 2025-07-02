{ pkgs }:
let
  cl = pkgs.claude-code;
in
  pkgs.runCommand cl.name {
    buildInputs = [ pkgs.makeWrapper ];
  } ''
  cp -r --no-preserve=mode ${cl} $out
  chmod +x $out/bin/claude
  wrapProgram $out/bin/claude \
    --set DISABLE_TELEMETRY 1 \
    --set CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC 1 \
    --set DISABLE_NON_ESSENTIAL_MODEL_CALLS 1 \
    --set ANTHROPIC_SMALL_FAST_MODEL claude-haiku-3
''
