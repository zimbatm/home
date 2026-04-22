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
#         packages/ask-local/bench.sh --mem      (adopt-trace-mem axis, see below)
set -euo pipefail

if [[ "${1:-}" == "--mem" ]]; then
  # adopt-trace-mem: does retrieval-augmented self-memory help Phi-3.8B on the
  # 20-case agent bench? cold = ASK_LOCAL_MEM=0 ×3 (median pass@1 + p50 ms);
  # warm = wipe runs.jsonl → one warm-up pass MEM=1 → sem-grep index-runs →
  # MEM=1 ×3. Bar: warm ≥ cold+3 AND dP50 ≤ +150ms. Decides --mem default +
  # llm-router rule for memory-shaped goals.
  CASES="$(dirname "$0")/bench-agent.jsonl"
  STATE="${XDG_STATE_HOME:-$HOME/.local/state}/ask-local"
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT

  pass_one() {  # $1=ASK_LOCAL_MEM → prints "pass p50_ms" for one 20-case sweep
    local pass=0 lat=() goal et es t0 out first
    while IFS= read -r line; do
      goal=$(jq -r .goal <<<"$line")
      et=$(jq -r .expect_tool <<<"$line")
      es=$(jq -r .expect_substr <<<"$line")
      t0=$(date +%s%3N)
      out=$(ASK_LOCAL_MEM="$1" ask-local --agent "$goal" 2>"$tmp/trace" || true)
      lat+=($(($(date +%s%3N) - t0)))
      first=$(awk '/^\[1\] /{print $2; exit}' "$tmp/trace")
      [[ "$first" == "$et" && "$out" == *"$es"* ]] && pass=$((pass + 1))
    done <"$CASES"
    local p50
    p50=$(printf '%s\n' "${lat[@]}" | sort -n | sed -n '10p')
    echo "$pass $p50"
  }
  median3() { sort -n | sed -n '2p'; }

  echo "== cold (ASK_LOCAL_MEM=0) =="
  cp=(); cl=()
  for i in 1 2 3; do
    read -r p l <<<"$(pass_one 0)"; cp+=("$p"); cl+=("$l")
    echo "  run$i: $p/20 p50=${l}ms"
  done
  cold=$(printf '%s\n' "${cp[@]}" | median3)
  cold_p50=$(printf '%s\n' "${cl[@]}" | median3)

  echo "== warm-up: populate runs.jsonl + sem-grep index-runs =="
  rm -f "$STATE/runs.jsonl"
  pass_one 1 >/dev/null
  sem-grep index-runs

  echo "== warm (ASK_LOCAL_MEM=1) =="
  wp=(); wl=()
  for i in 1 2 3; do
    read -r p l <<<"$(pass_one 1)"; wp+=("$p"); wl+=("$l")
    echo "  run$i: $p/20 p50=${l}ms"
  done
  warm=$(printf '%s\n' "${wp[@]}" | median3)
  warm_p50=$(printf '%s\n' "${wl[@]}" | median3)

  d=$((warm_p50 - cold_p50))
  verdict=FAIL; ((warm >= cold + 3 && d <= 150)) && verdict=PASS
  echo
  echo "cold=${cold}/20 warm=${warm}/20 dP50=+${d}ms ${verdict}"
  exit 0
fi

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
