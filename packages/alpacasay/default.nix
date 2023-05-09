{ cowsay, writeScriptBin }:
# When squinting, the alpaca looks a lot like a llama
writeScriptBin "alpacasay" ''
  #!/bin/sh -e
  ${cowsay}/bin/cowsay -f ${./llama.cow} "$@"
''
