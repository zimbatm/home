# Tool hints — keep output small

Referenced from BASE_SETUP. The cost is the *output landing in context*,
not the call. `token-cost.sh --by-tool` shows your profile.

## Prefer native tools over Bash equivalents

| Instead of | Use | Why |
|---|---|---|
| `cat FILE` / `cat FILE \| head -N` | `Read({file_path, limit:N})` | line-numbered, ranged, no shell envelope |
| `sed -n 'A,Bp' FILE` | `Read({file_path, offset:A, limit:B-A})` | same |
| `ls -la DIR` / `ls -R` | `Glob({pattern})` or `find -maxdepth N -printf '%p\n'` | columns/perms are noise; you want paths |
| `grep -rn PAT DIR` | `Grep({pattern, path, -n:true})` or `rg -n --no-heading` | native Grep returns structured; rg is faster |

## When you must shell

| Instead of | Use |
|---|---|
| `git log -p -- PATH` | `git log --oneline --numstat -- PATH` first; `-p` only on the one commit you need |
| `git diff` | `git diff --stat` or `--name-only` first; full diff on demand |
| `nix build 2>&1 \| tail -N` | `nix build --log-format bar-with-logs 2>&1 \| tail -N` (drops the per-drv "building…" spam) or `--log-format internal-json \| jq 'select(.type=="msg")'` |
| `journalctl -u X -n N` | `journalctl -u X -n N -o cat` (drop timestamp/host prefix) or `-o json \| jq -r .MESSAGE` |
| `nix eval EXPR` (errors) | `iets eval EXPR` where available — span-addressed errors |

## Structural / typed (devshell additions)

| Task | Tool | Note |
|---|---|---|
| Find defs/callsites/patterns by syntax | `ast-grep -p 'PATTERN' -l LANG` | tree-sitter; regex breaks on code structure, this doesn't. Invoke as `ast-grep` (NOT `sg` — that's setgroups). |
| Pull one field from any `--json` | `… --json \| gron \| grep KEY` | flatten-then-grep; avoids jq syntax for one-offs |
| Hard-to-parse CLI output (`ip`, `ss`, `systemctl show`) | `cmd \| jc --cmd \| jq -r .FIELD` | only when text genuinely ambiguous — JSON envelope often costs more |
| LoC by language | `tokei -o json` or plain `tokei` | replaces `find … \| xargs wc -l` |
| "What does this module export?" (Rust/Go/TS) | `zat FILE` | symbols + line ranges, ~16× smaller than cat. No Nix support. |
| Gate cmd: only show failures/errors | `rtk test CMD` / `rtk err CMD` | strips passing-test noise; what mergeGate.cmd wants |

**Don't** use `rg --json` (4-7× larger than `rg -n`), difftastic/nom (human-pretty = more bytes), or rtk's global hook (disciplined alternatives are tighter; use `rtk err`/`rtk test` standalone).

## Always

- **Never install on the host.** No `apt-get`/`pip install`/`npm -g`/`curl|sh`. Use `nix shell nixpkgs#TOOL -c …`, add to the devshell, or package it. If a tool isn't in nixpkgs, write a derivation — don't reach for the system package manager.
- Cap output: `\| head -N` or `\| tail -N` on anything that might be unbounded.
- One dense Bash with a shell `for` loop, not N separate Bash calls (each call ≈ 2KB envelope).
- Read what you need, not the whole file.
