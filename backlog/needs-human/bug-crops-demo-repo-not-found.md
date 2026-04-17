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

**Triage done (a767724, sans gh-auth):**
- Differential `git ls-remote` with the same deploy key: `assise/kin`
  and `assise/nix-skills` both succeed, `assise/crops-demo` alone 404s
  → **not** broad credential loss.
- `curl -I https://github.com/assise/crops-demo` → 404, no Location
  redirect → **not** a rename (GitHub 301-redirects renamed repos).
- Remaining causes: **per-repo access drop** (went private / deploy
  key removed from this repo only) or **deletion**. Both require an
  assise GitHub org admin to check repo settings.

**Cross-filed:** `../crops-demo/backlog/bug-origin-unreachable.md` @
02f28fc — local-only, push fails on the same 404.

**Mitigation attempted:** prefetch shim (`.claude/workflows/prefetch-sibling-inputs.sh`
seeding from `/root/src/crops-demo`) — abandoned, denylist forbids
backlog-item branches touching `.claude/`. See
`backlog/tried/bug-crops-demo-repo-not-found.md`. A human can commit
that helper directly as a harness change if wanted.

**How much:** ~5min once an org admin confirms private-vs-deleted.
Then either re-grant access (no flake change), update `flake.nix`
inputs.crops-demo.url, or vendor/drop the input.

**Blockers:** assise GitHub org admin access. Re-verified 2026-04-15
meta r2: ls-remote still `Repository not found`.

---

**Update 2026-04-17 (drift @ 5858216):** repo was **recreated** upstream
— 5858216 (zimbatm `flake update`) bumped lock to `0182fa2c` revCount=1
(was cad8614b revCount=301; old history discarded). zimbatm's key
reaches it; this worker's still 404s (`git ls-remote` re-confirmed) and
`/root/src/crops-demo` lacks 0182fa2c. So: not deleted — **recreated
private**, deploy-key not re-granted on the new repo. Ask: re-add the
grind worker deploy key to assise/crops-demo settings. Acute eval
breakage filed separately at backlog/bug-eval-broken-crops-demo-5858216.md.
