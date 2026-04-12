# adopt: man-here — version-exact docs from the nix store

## What

`man-here <cmd>` → compact markdown built from what's *actually
installed*: resolve `cmd` to its store path, emit the derivation's
`meta.description`, the rendered man page (via `mandoc -T utf8` →
stripped), `--help` output, and any `$out/share/doc/*/README*`. Ship as
a skill so the agent reaches for it before WebFetch when asking "how do
I use X."

Stretch: when `cmd` isn't in PATH, fall back to `nix-locate 'bin/<cmd>'`
and pull the man page from the binary cache (`nix store cat`) without
installing — "what would this do" answered offline.

## Why

Mic92/mics-skills ships `context7-cli` for the same need (agent wants
library/tool docs mid-task). Context7 is a hosted API: needs a key,
needs network, and returns *latest-upstream* docs — which on a NixOS
box pinned to a 3-week-old nixpkgs is the wrong version often enough to
matter.

Our angle: nv1's `/nix/store` already contains the authoritative docs
for every binary in PATH, at the exact version that will run. No key, no
network, no version skew. The store *is* the docs index; we just need a
reader. This is a NixOS-shaped answer Context7 can't give.

## How much

~0.4r. `packages/man-here/`: one writeShellApplication (~60 lines —
`readlink -f $(command -v)`, `nix-store -q --deriver` →
`meta.description` via `nix eval`, `man -P cat`, capped `--help`,
`find $out/share/doc`). SKILL.md alongside. nix-locate fallback adds
~20 lines and reuses the existing `nix-index-database` input (already
wired in `modules/home/terminal`, no new flake input).

## Falsifies

- Whether man + `--help` is rich enough for agent use, or Context7's
  curated/LLM-preprocessed extracts are materially better and we end up
  wanting the API anyway.
- Whether version-exactness is load-bearing in practice: does the agent
  ever get burned by upstream-latest docs on a pinned system, or is the
  skew small enough that Context7's breadth wins.
- Whether `nix-index` man-page-from-cache works without realising the
  whole output (it should — narinfo + `nix store cat` on one file).

## Source

Mic92/mics-skills `context7-cli` (Context7 hosted docs API wrapper).
Surveyed 2026-04-12. awesome-nix's MCP-NixOS covers package/option
*metadata* lookup — adjacent but not docs; `kin-opts` already owns the
option-tree half here.
