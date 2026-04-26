# bug: ask-cuda one-shot completion runs away

## What

`ask-cuda "<prompt>"` (the non-`--serve` path in
`packages/ask-cuda/default.nix`) doesn't exit after the requested `-n N`
tokens. With `-no-cnv -n 24 --no-display-prompt -p "..."` on
llama.cpp b8770, llama-cli generates indefinitely — observed
**1.77 GB of stdout in 5 min** before SIGINT, with `wchar` climbing
linearly. Bench mode (`llama-bench`) and the same model + flag set
work correctly, so the regression is in `llama-cli`'s flag interaction,
not the CUDA build or the model.

## Why

`--serve` mode (llama-server :8089) and `llama-bench` are both wired
and work — the package is useful as-is. The one-shot CLI path is a
nicety. Filing rather than blocking the CUDA / Qwen3.6-35B-A3B commit
since the bench numbers (3.74 t/s gen at ncmoe=20) are the load-bearing
result.

## How much

Two paths to investigate:

1. **Try `--single-turn` (`-st`) instead of `-no-cnv`.** llama.cpp help
   says `-st` "run conversation for a single turn only, then exit when
   done". May be the post-1.6 idiom for what `-no-cnv` used to do.
2. **Drop `--no-display-prompt`.** Possible interaction: with prompt
   suppressed and conversation off, llama-cli may loop trying to print
   *something* before respecting `-n`.

Reproducer (10s round-trip, no model load needed if cached):

```sh
/nix/store/...llama-cpp-8770/bin/llama-cli \
  -m ~/.local/share/llama/Qwen3.6-35B-A3B-UD-IQ3_XXS.gguf \
  -ngl 99 -ncmoe 20 -fa 1 -ctk f16 -ctv f16 \
  -no-cnv -n 8 -p 'Hi.' 2>&1 | head -200
```

Expected: 8 tokens then exit. Actual: indefinite output.

## Blockers

None — purely a CLI ergonomics fix. `llama-server` + curl is the
working alternative for one-shot completions today.
