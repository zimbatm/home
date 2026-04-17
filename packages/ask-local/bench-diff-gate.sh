#!/usr/bin/env bash
# bench-diff-gate.sh — label-set scaffold for adopt-diff-gate.
#
# Falsifies: 3.8B risk-triage at hook latency. Target ≥0.8 recall on
# needed-review at <2s p95 on Arc. Below that, llm-router /review keeps
# the linecount fallback as primary and the model gate is noise.
#
# First pass emits TSV with the label column blank — hand-fill it
# (lockout-recovery-adjacent commits = 1, flake.lock-only = 0, etc.),
# then re-run against the labelled file to get recall + p95.
#
# usage:  packages/ask-local/bench-diff-gate.sh [N] [labels.tsv]
set -euo pipefail

N="${1:-50}"
LABELS="${2:-}"

if [[ -z "$LABELS" ]]; then
  printf 'sha\tpredicted\tms\tlabel\tsubject\n'
  git -C "${BENCH_REPO:-.}" log -n "$N" --no-merges --format=%H | while read -r sha; do
    diff=$(git -C "${BENCH_REPO:-.}" show -p --format= "$sha")
    subj=$(git -C "${BENCH_REPO:-.}" log -1 --format=%s "$sha")
    t0=$(date +%s%3N)
    if ask-local --diff-gate <<<"$diff" >/dev/null 2>&1; then pred=low; else pred=high; fi
    t1=$(date +%s%3N)
    printf '%s\t%s\t%d\t\t%s\n' "$sha" "$pred" "$((t1 - t0))" "$subj"
  done
  exit 0
fi

# Labelled: compute recall on needed-review (label=1) and p95 latency.
awk -F'\t' '
  NR==1 { next }
  $4!="" {
    n++; ms[n]=$3
    if ($4==1) { need++; if ($2=="high") tp++ }
    if ($4==0 && $2=="high") fp++
  }
  END {
    if (need==0) { print "no positive labels"; exit 1 }
    asort(ms); p95=ms[int(n*0.95)+(n*0.95>int(n*0.95))]
    printf "n=%d  recall=%.2f  fp=%d  p95=%dms\n", n, tp/need, fp, p95
    printf "verdict: %s\n", (tp/need>=0.8 && p95<2000) ? \
      "PASS — flip llm-router /review gate to model-primary" : \
      "FAIL — keep linecount primary"
  }
' "$LABELS"
