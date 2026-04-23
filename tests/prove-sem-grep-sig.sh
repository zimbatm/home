#!/usr/bin/env bash
# prove: `sem-grep sig` returns `score  path:line  signature` lines and
# matches Rust definitions. Guards both the output shape (agents Read at
# the file:line) and the rust grammar wiring in SEM_GREP_GRAMMARS.
command -v sem-grep >/dev/null || { echo "skip: sem-grep not on PATH"; exit 0; }
[[ -f "${SEM_GREP_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/sem-grep}/index.db" ]] \
  || { echo "skip: index absent (runs on nv1 post-deploy)"; exit 0; }
trap 'pty-puppet @sg-sig kill 2>/dev/null || true' EXIT
pty-puppet @sg-sig spawn bash -c 'sem-grep sig -n 20 "rust function parse" 2>&1; echo PROVE_DONE'
pty-puppet @sg-sig expect 'PROVE_DONE' --timeout 30
pty-puppet @sg-sig expect '[0-9]\.[0-9]{3}  [^ ]+\.rs:[0-9]+  .*fn '
