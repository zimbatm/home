# ops: deploy nv1 (assise:// rotate completion)

relay1 + web2 are on `assise://` certs (deployed @all 2026-04-11). nv1
is unreachable from the meta admin host (mesh-ULA-only, no public IP),
so it's still on `kin://` certs and **cannot peer** with relay1/web2
until deployed.

## Do (from a mesh-connected host or nv1 itself)

```sh
cd ~/src/home && git pull
nix develop -c kin --evaluator nix deploy nv1 --local  # if on nv1
# or: kin --evaluator nix deploy nv1                   # if mesh-reachable
```

`--evaluator nix` is required (iets's replaceStrings backslash bug
rejects nv1's swap unit name; see iets/backlog/bug-replacestrings-
backslash-escape.md).

## After

Probe: `cat /etc/kin/identity/id` → `assise://…/machine/nv1`;
`systemctl status kin-mesh` → active and peered with relay1/web2.
Then close this. (crush already restored df81a08; bug-crush-goproxy-leak
closed f16c924 — that follow-up is done.)
