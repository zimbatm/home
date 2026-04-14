# adopt: hist-sem — semantic shell-history recall on the NPU index

## What

Extend `sem-grep`'s sqlite+OpenVINO embedding store with a second
table fed by a zsh `precmd` hook: one row per command =
`(ts, cwd, cmd, exit, embedding)`. New verb `sem-grep hist "<english>"`
(or thin `hist-sem` alias) ranks history by cosine against the query
embedding, prints the top commands with cwd+date, and on
`--pick` drops the chosen one onto the readline buffer via
`print -z`. Encoder is the same MiniLM the file index already uses —
no new model download.

## Why

Literal/fuzzy history (ctrl-r, mcfly, atuin) fails when you remember
*what the command did* but not *what it was called*: "that ffmpeg line
that fixed the audio drift", "the nix eval that showed closure size".
Mic92 ships `db-cli` (generic SQL-as-skill) and atuin; neither does
intent-match. nv1 already runs a sentence-transformer on the NPU for
`sem-grep` and for `live-caption-log` fold-in — shell history is the
obvious third corpus, and it's the one an agent in a terminal actually
wants ("how did Jonas run this last time?").

## How much

~0.5r. Reuses `packages/sem-grep`'s python encoder verbatim (subset of
transcribe-npu's closure, already on nv1). Add: (a) ~15 LoC zsh hook in
`modules/home/terminal` writing JSONL to
`$XDG_STATE_HOME/hist-sem/log.jsonl`, (b) ~40 LoC `hist` subcommand in
sem-grep that batch-embeds new rows on first query (lazy, NPU via
infer-queue if >5s) and serves cosine top-k from sqlite.

## Falsifies

Can a general sentence-transformer usefully embed shell one-liners, or
is the domain (flags, paths, hashes) too far OOD for MiniLM? Cheap to
test: seed with current `~/.zsh_history`, hand-score 10 recall queries.
If precision is poor, that's a data point against "one NPU embedding
model for everything" and toward a code-specific encoder — which would
also affect `sem-grep`'s file index.
