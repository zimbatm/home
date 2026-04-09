# kin user schema drift: `recipientOnly` unknown

**What:** All 3 hosts fail dry-build on origin/main@fedacd7 with
`The option users.zimbatm-yk.recipientOnly does not exist` (kin.nix:15).
Pinned kin suggests `admin`/`profile`/`groups` instead.

**Why:** Either kin dropped/renamed the `recipientOnly` user option, or
kin.nix adopted it before the kin pin shipped it. Blocks the dry-build
gate for every grind round until resolved.

**How much:** Drift specialist — check kin changelog for the option;
either (a) bump kin if it's now present upstream, (b) file
../kin/backlog/bug-user-recipientonly.md if kin removed it, or
(c) drop/rename the line in kin.nix:15 if it was speculative.

**Blockers:** none — read-only triage first.
