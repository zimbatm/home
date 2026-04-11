{ pkgs, ... }:
# Request-shape proxy: 127.0.0.1:8090 → ask-local :8088 (short, no-tools,
# ≤4k ctx) or upstream. Stdlib-only python3; logs every decision to
# $XDG_STATE_HOME/llm-router/decisions.jsonl. Opt-in via
#   export OPENAI_BASE_URL=http://127.0.0.1:8090/v1
# — agentshell env wiring is a deliberate ops-* follow-up.
pkgs.writers.writePython3Bin "llm-router" {
  flakeIgnore = [ "E501" ];
} ./llm-router.py
