#!/usr/bin/env bash
# bench.sh — 4-case tok/s matrix for adopt-lookup-decode on Arc vulkan.
#
# Falsifies: does GBNF-constrained output boost prompt-lookup draft acceptance
# enough to matter on a Meteor Lake iGPU? Hypothesis: grammar+lookup ≫
# grammar-alone ≫ free+lookup. If grammar+lookup ≈ grammar-alone the iGPU is
# compute-bound and the draft premise is dead on this hardware.
#
# Runs against the wrapper on PATH (post ops-deploy-nv1). The lookup cases call
# the underlying llama-lookup/llama-cli directly so stderr stats are visible
# (the wrapper sinks 2>/dev/null for interactive use).
#
# usage:  packages/ask-local/bench.sh [N_REPEAT]
set -euo pipefail

REPEAT="${1:-3}"
MODEL="${ASK_LOCAL_MODEL:-${XDG_DATA_HOME:-$HOME/.local/share}/llama/Phi-3-mini-4k-instruct-Q4_K_M.gguf}"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/ask-local"
mkdir -p "$CACHE"
[[ -f "$MODEL" ]] || { echo "bench: model missing: $MODEL (run ask-local once for fetch hint)" >&2; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Same shape as ptt-dictate's generated intent grammar.
cat >"$tmp/intent.gbnf" <<'EOF'
root   ::= "{\"type\":\"" intent "\",\"arg\":\"" arg "\"}"
intent ::= "ask" | "open" | "search" | "type" | "text"
arg    ::= [^"\\\x7f\x00-\x1f]*
EOF

PROMPT_G="Classify the voice command into one of: ask, open, search, type. Use 'text' if none fit. Put any free-text argument in arg.
Command: open a terminal in the projects directory
JSON:"
PROMPT_F="In one short paragraph, explain why prompt-lookup decoding helps when output entropy is low."

# decode tok/s + accept% from a stderr capture (handles both binaries)
parse() {
  local f="$1"
  local tps acc
  # llama-lookup: "decoded N tokens in T seconds, speed:   X t/s"
  tps=$(grep -oE 'decoded[^,]+, speed:[[:space:]]+[0-9.]+' "$f" | grep -oE '[0-9.]+$' || true)
  # llama-cli:    "eval time = ... ,   X tokens per second)"
  [[ -n "$tps" ]] || tps=$(grep -E '^llama_perf_context_print:.* eval time' "$f" \
    | grep -oE '[0-9.]+ tokens per second' | grep -oE '^[0-9.]+' || true)
  acc=$(grep -oE 'accept[[:space:]]*=[[:space:]]*[0-9.]+%' "$f" | grep -oE '[0-9.]+' || echo "-")
  printf '%s\t%s\n' "${tps:-?}" "$acc"
}

run() {
  local label="$1" bin="$2"; shift 2
  local best="?" acc="-"
  for ((i = 1; i <= REPEAT; i++)); do
    "$bin" -m "$MODEL" -ngl 99 "$@" >/dev/null 2>"$tmp/err"
    read -r tps a <<<"$(parse "$tmp/err")"
    [[ "$tps" != "?" ]] || continue
    awk -v t="$tps" -v b="$best" 'BEGIN{exit !(b=="?"||t>b)}' && best="$tps"
    acc="$a"
  done
  printf '%-18s %10s  %8s\n' "$label" "$best" "$acc"
}

printf '%-18s %10s  %8s\n' "case" "tok/s" "accept%"
printf '%-18s %10s  %8s\n' "----" "-----" "-------"
run "free   / cli"    llama-cli    -n 128 -p "$PROMPT_F" --no-display-prompt
run "free   / lookup" llama-lookup -n 128 -lcd "$CACHE/bench-free.ngram"   --draft-max 16 --color off -p "$PROMPT_F"
run "grammar/ cli"    llama-cli    -n 128 --grammar-file "$tmp/intent.gbnf" -p "$PROMPT_G" --no-display-prompt
run "grammar/ lookup" llama-lookup -n 128 --grammar-file "$tmp/intent.gbnf" -lcd "$CACHE/bench-gram.ngram" --draft-max 16 --color off -p "$PROMPT_G"

echo
echo "verdict: grammar/lookup ≫ grammar/cli → flip --grammar to auto --fast"
echo "         grammar/lookup ≈ grammar/cli → iGPU compute-bound, drop adopt-lookup-decode"
