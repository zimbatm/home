#!/usr/bin/env bash
set -euo pipefail

if [[ $# = 0 ]]; then
  set -- switch
fi

exec nixos-rebuild --flake .#web1 --target-host root@95.216.188.155 "$@"
