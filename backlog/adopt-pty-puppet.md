# adopt-pty-puppet — session-keyed expect/send for agents

## what

`packages/pty-puppet/` — a tiny CLI that lets an agent drive interactive
terminal programs over a named pty session:

    pty-puppet @wifi spawn nmtui
    pty-puppet @wifi snap                 # dump current screen text
    pty-puppet @wifi send $'\r\r'         # navigate
    pty-puppet @wifi expect 'Activate a connection' --timeout 5
    pty-puppet @wifi kill

Sessions live under `$XDG_RUNTIME_DIR/pty-puppet/<name>` so multiple
named sessions coexist (mirrors infer-queue's lane model). Ship in
`agentshell` + desktop hm.

## why

Mic92's `mics-skills` ships `pexpect-cli` so Claude can drive TUIs. We
have `agent-eyes` (peek/poke) for the Wayland pixel layer, but nothing
at the pty text layer — and agent-eyes is the wrong hammer for `nmtui`,
`gdisk -l`, `nix repl`, ssh known-hosts prompts, `gpg --gen-key`: you
want text expect/send, not screenshot+OCR+raw keycodes. Gap sits between
Bash (refuses interactive) and agent-eyes (full GUI).

Our angle, not Mic92's: session-keyed verbs over a persistent backend
rather than a one-shot pexpect script. Backend = `tmux -L pty-puppet`
(send-keys / capture-pane -p) — zero new deps, pueue-style robustness,
`snap` is just capture-pane. pexpect only if tmux proves insufficient.

## how much

~60 LoC `writeShellApplication` wrapping `tmux -L pty-puppet -f /dev/null`.
`expect` = poll capture-pane for regex with timeout. No daemon beyond the
tmux server (auto-spawns, auto-dies). Add to `flake.nix` packages list +
`agentshell` paths + `modules/home/desktop` home.packages.

## falsifies

Can an agent self-serve TUI-only ops on nv1 — join wifi via nmtui,
inspect partitions via gdisk, poke `nix repl` for a quick eval — without
a human relaying screen contents? If yes, shrinks the needs-human/ set.

## blockers

None. tmux already in closure via terminal hm.
