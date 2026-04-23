#!/usr/bin/env bash
# prove: ask-local --fast emits the prompt verbatim on stdout (plain text,
# not JSON). llama-lookup has no --no-display-prompt so the prompt echoes;
# agent.py:ask() relies on this to strip-then-regex the trailing JSON.
# If --fast ever flipped to suppressed/JSON output, agent.py breaks silently.
command -v ask-local >/dev/null || { echo "skip: ask-local not on PATH"; exit 0; }
[[ -f "${ASK_LOCAL_MODEL:-${XDG_DATA_HOME:-$HOME/.local/share}/llama/Phi-3-mini-4k-instruct-Q4_K_M.gguf}" ]] \
  || { echo "skip: model absent (runs on nv1 post-deploy)"; exit 0; }
trap 'pty-puppet @ask-fast kill 2>/dev/null || true' EXIT
pty-puppet @ask-fast spawn bash -c 'ask-local --fast "Q: two plus two? A:" | head -c 400; echo; echo PROVE_DONE'
pty-puppet @ask-fast expect 'PROVE_DONE' --timeout 60
pty-puppet @ask-fast expect 'Q: two plus two\? A:'
