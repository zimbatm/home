#!/usr/bin/env bash
set -euo pipefail

exec nixos-anywhere -f .#web1 root@95.216.188.155
