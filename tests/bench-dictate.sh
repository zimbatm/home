#!/usr/bin/env bash
# bench: dictation latency across the three transcribe backends, idle vs under
# ask-local load. Falsifies adopt-parakeet-cpu-lane: if transcribe-cpu p95 beats
# vulkan p95 by ≥200 ms while ask-local --agent is serving, lane-pressure routing
# is the right shape and ptt-dictate --backend=auto becomes the default. If
# parakeet-cpu loses even at idle, drop the package — the 2-lane split was right.
#
# Runs on nv1 post-deploy (needs Arc + NPU + the FOD models realised). Elsewhere
# it skips like prove-ask-local-fast.sh.
set -euo pipefail
for b in transcribe-npu transcribe-cpu ask-local whisper-cli jq; do
  command -v "$b" >/dev/null || { echo "skip: $b not on PATH"; exit 0; }
done
WMODEL="${PTT_DICTATE_MODEL:-${XDG_DATA_HOME:-$HOME/.local/share}/whisper/ggml-base.en.bin}"
[[ -f "$WMODEL" && -e /dev/accel/accel0 ]] \
  || { echo "skip: model/NPU absent (runs on nv1 post-deploy)"; exit 0; }

N=20
TMP=$(mktemp -d /tmp/bench-dictate.XXXX)
trap 'kill "${LOAD_PID:-0}" 2>/dev/null; rm -rf "$TMP"' EXIT

# Fixed utterances → 16 kHz mono wavs via piper (already in profile for say-back).
i=0
while read -r line; do
  printf %s "$line" | piper --model "${SAY_BACK_VOICE:-en_GB-alan-low}" \
    --output_file "$TMP/u$i.wav" >/dev/null 2>&1
  i=$((i+1))
done <<'UTT'
open a new terminal
what time is it in tokyo
summarise the last commit
switch to workspace three
take a screenshot of the focused window
search the web for nixos parakeet
mute the microphone
paste from clipboard history
lock the screen
reply to the last slack message
show me gpu utilisation
restart the wifi service
open the home flake in the editor
what is two hundred and fifty six times twelve
read the top headline aloud
move this window to the left monitor
start a five minute timer
transcribe the meeting recording
toggle do not disturb
commit all staged changes with message fix typo
UTT

run_backend() {
  case "$1" in
    arc) whisper-cli -m "$WMODEL" -f "$2" --no-timestamps --no-prints 2>/dev/null ;;
    npu) transcribe-npu "$2" 2>/dev/null ;;
    cpu) transcribe-cpu "$2" 2>/dev/null ;;
  esac
}

pctl() { sort -n | awk -v p="$1" '{a[NR]=$1} END{print a[int((NR*p+99)/100)]}'; }

bench_state() {
  local state="$1"
  for be in arc npu cpu; do
    run_backend "$be" "$TMP/u0.wav" >/dev/null  # warm
    : >"$TMP/$be.$state.ms"
    for i in $(seq 0 $((N-1))); do
      t0=$(date +%s%3N)
      run_backend "$be" "$TMP/u$i.wav" >/dev/null
      echo $(( $(date +%s%3N) - t0 )) >>"$TMP/$be.$state.ms"
    done
    p50=$(pctl 50 <"$TMP/$be.$state.ms"); p95=$(pctl 95 <"$TMP/$be.$state.ms")
    printf '%-6s %-5s p50=%4dms p95=%4dms\n' "$state" "$be" "$p50" "$p95"
  done
}

echo "== idle =="
bench_state idle

echo "== under ask-local --agent load =="
( while true; do ask-local --agent "list files in the current directory" >/dev/null 2>&1; done ) &
LOAD_PID=$!
sleep 2  # let Phi-3 land on the Arc
bench_state load
kill "$LOAD_PID" 2>/dev/null; wait "$LOAD_PID" 2>/dev/null || true

# Verdict
arc_load=$(pctl 95 <"$TMP/arc.load.ms")
cpu_load=$(pctl 95 <"$TMP/cpu.load.ms")
delta=$(( arc_load - cpu_load ))
echo
echo "verdict: cpu vs arc p95 under load: ${delta}ms (pass bar ≥200ms)"
[[ $delta -ge 200 ]] && echo "PASS: lane-pressure routing wins; flip --backend=auto to default" \
                     || echo "FAIL: parakeet-cpu does not beat vulkan under load"
