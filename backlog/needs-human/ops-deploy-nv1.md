undefined
---

## drift @ d2ad1d1 (2026-04-14): probe unblind; nv1 deployed off-main

`kin status --json` from this worker now returns live data for all 3
hosts (no `not-on-mesh`, no publickey-denied). Unblind path: 007ccaa
`kin gen` re-signed gen/identity/user-claude/_shared/certs for the
current worker key; deployed sshd already trusts home-CA, so the local
cert suffices — ops-worker-ssh-reauth resolved without needing 007ccaa
itself deployed.

**relay1 + web2: have == want** (relay1 `dpxnfwvk…`, web2
`zv4kapl1…`; health=running, secrets=active, failed=-). Human deployed
both at or after e50356f. `ops-deploy-relay1-web2.md` deleted — gap
closed. One web2 runtime check carried here: `systemctl status
restic-backups-gotosocial.{service,timer}` (e50356f hourly→rsync.net;
`kin set` for rsyncnet password must have landed or first timer fire
will fail).

**nv1: have ≠ want.**
```
have: /nix/store/gfcs7jg5f5k5zb0yy9wf2jmqip1rjcgf-nixos-system-nv1-26.05.20260409.4c1018d
want: /nix/store/db5j0ss1r5hqr9rchqfpwlhszv070405-nixos-system-nv1-26.05.20260409.4c1018d
```
uptime 0d18h (boot ~2026-04-13 18:40Z). want `db5j0ss1` is stable
since c170da0 — e50356f (gotosocial, web2-only) and d2ad1d1 (harness)
are nv1-closure-neutral.

**have `gfcs7jg5` matches NO commit on origin/main.** Evaluated nv1
toplevel at 7 points 821a88e..c170da0 (p8rjl6gv, 7y92ns00, pln9jmzq,
dvvzcpy6, 6xjfsk8i, 1y04sk7i, db5j0ss1) — none match. nv1 was deployed
from a dirty tree or an off-branch ref. Reconcile = `kin deploy nv1`
to bring it to a reproducible state; if the off-main delta was
intentional, commit it first.

New nv1-affecting commits since e8c0ad4 refresh (9; 9b55b4e nv1=hb3ac25
already noted by bumper):

- 1a5519c / d60c257 — man-here pkg + skill (terminal/default.nix)
- 3b08f00 / 821a88e — tab-tap pkg + Firefox native-messaging extension
- 9b55b4e — kin/iets bump (d5b44cb / 62a6681)
- c03a8a8 — nixvim bump (3682e0d)
- 7cb19d4 — dconf custom-keybinding `<Super>Return`→ghostty (fix hm-activation registry wipe)
- 7d300c5 — foot as default terminal; `<Super>Return`→foot
- 007ccaa — users.claude.sshKeys rotate + gen/ re-sign
- dacd1ec — crops.nix: drop run-crops (IFD via crane; `nix run crops-demo#run-crops` ad-hoc instead)
- c170da0 — packages/nvim: enableMan=false (eval -19%)

**Three new runtime checks:**
- foot — `<Super>Return` opens foot (server mode); ghostty still
  launchable
- tab-tap — Firefox about:addons lists tab-tap; `tab-tap read` from a
  shell returns Readability text of the active tab
- man-here — `man-here jq` (or any PATH CLI) renders store-exact docs

Deploy + runtime-checks list remain the only human-gated work. The
**off-main `have`** is the new flag — confirm no intentional local
delta on nv1 before deploy overwrites it.
