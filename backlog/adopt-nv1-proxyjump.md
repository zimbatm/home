# adopt machines.nv1.proxyJump = "relay1"

**What:** Set `machines.nv1.proxyJump = "relay1"` in kin.nix, then `kin
gen` to regenerate `gen/ssh/_shared` + manifest.

**Why:** kin@ea0d9b8 (landed in this repo via bump f0f20988) grew
`machines.<n>.proxyJump` — exactly the feature filed from here as
`../kin/backlog/feat-machine-proxyjump.md` (drift commit 82d7737). With
it set, `kin status nv1` / `kin deploy nv1` from a non-mesh worker
threads `-o ProxyJump=root@95.216.188.155` automatically; drift-checker
drops the manual `-J` workaround documented in `backlog/drift-nv1.md`.

**How much:** One-line kin.nix edit (machines block, line 22 — add
`proxyJump = "relay1";` to the nv1 attrset). `kin gen` rewrites
gen/ssh/_shared with `ProxyJump relay1` under the nv1 Host block and
manifest.lock rehashes. Spine touch → solo pick.

**Blockers:** None. kin ≥ f0f20988 is locked as of this commit. Verify
with `kin gen --check` after; gate is the usual 3-host eval+dry-build.

**Follow-up after merge:** Update `backlog/drift-nv1.md` to drop the
"Structural: kin status nv1 blind" section + manual `-J` workaround.
