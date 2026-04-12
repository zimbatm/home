---
name: man-here
description: Version-exact docs for any CLI in PATH, assembled from /nix/store — package id, rendered man page, --help, README. Reach for this BEFORE WebFetch when you need to know how an installed tool works; the store has the authoritative docs for the exact version that will run.
---

When you're about to look up how a CLI works (flags, subcommands, config
format) and the binary is on this machine, query the store first:

```sh
man-here <cmd>         # markdown: store path, man page (≤200L), --help (≤80L), README*
man-here --raw <cmd>   # uncapped — full man page
```

Output is built from `/nix/store` — the *exact* version in PATH, not
upstream-latest. No network, no API key, no version skew against a pinned
nixpkgs. If `<cmd>` isn't installed, `man-here` falls back to `nix-locate`
and names the providing attr so you can `nix shell nixpkgs#<attr>` or add
it to `home.packages`.

**Prefer this over WebFetch/WebSearch** for "how do I use jq / rg / fd /
git-absorb / kin / …". WebFetch is for docs the store can't carry: web
APIs, hosted services, language-library references.
