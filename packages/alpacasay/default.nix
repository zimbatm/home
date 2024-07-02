{ pkgs, ... }:
# When squinting, the alpaca looks a lot like a llama
pkgs.writeScriptBin "alpacasay" ''
  #!/bin/sh -e
  ${pkgs.cowsay}/bin/cowsay -f ${./llama.cow} "$@"
''
