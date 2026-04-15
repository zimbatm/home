# crops-demo flake input: GitHub returns "Repository not found"

**What:** `flake.lock` pins `crops-demo` to
`ssh://git@github.com/assise/crops-demo` @ cad8614b. As of 2026-04-15
that URL returns `ERROR: Repository not found.` from this worker
(both `nix eval` lazy-fetch and `git ls-remote`). Same for
`git -C /root/src/crops-demo fetch origin`.

**Why it matters:**
- `nix eval .#nixosConfigurations.nv1…` fails on a cold cache (nv1 is
  the only consumer). Drift-checker and `kin status` die at the eval
  step until the source is in store.
- `nix flake update crops-demo` will fail — bumper can't bump it.
- Fresh clones / new workers can't build nv1 at all.

**Workaround used this round:** `/root/src/crops-demo` has the locked
rev locally; `nix flake prefetch git+file:///root/src/crops-demo?rev=cad8614b…`
populates the git cache with matching narHash, after which the
ssh:// locked entry resolves from cache without re-fetching.

**Likely causes (pick one):**
1. Repo renamed (e.g. `assise/crops` or moved org) — update
   `flake.nix` inputs.crops-demo.url + `nix flake lock --update-input
   crops-demo`.
2. Repo went private and this worker's deploy key lost access —
   re-grant, no flake change.
3. Repo deleted — vendor the bits nv1 actually uses or drop the input.

**How much:** ~5min once cause is known. Check
`gh repo view assise/crops-demo` from an authenticated session, or ask
in the crops-demo sibling grind what changed.

**Blockers:** Needs GitHub auth this worker doesn't have (`gh auth
status` = not logged in) to distinguish rename vs access-loss vs
delete. Filing for triage; not needs-human (a worker with gh auth can
resolve).
