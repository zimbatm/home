# eval broken @ HEAD: 5858216 bumped crops-demo to unfetchable rev

**What:** 5858216 (`flake update`, zimbatm out-of-band) bumped
`crops-demo` cad8614b→0182fa2c (revCount 301→1 — repo was deleted+
recreated upstream). This worker's deploy key still 404s on
`ssh://git@github.com/assise/crops-demo` (re-verified `git ls-remote`
2026-04-17), and `/root/src/crops-demo` lacks 0182fa2c (has old history
through cad8614b only). Result: `nix eval .#nixosConfigurations.*` and
`kin status` both die at the crops-demo fetch — **gate fails all 3
hosts**.

Eval at 5858216~1 (3f3124d) works fine; cad8614b is store-cached.

**Why:** Gate (all 3 hosts eval+dry-build) is the grind invariant.
Broken gate = no merge can land. drift-checker can't compute fresh
`want` paths past 3f3124d.

**How much:** ~2min — flake.lock-only edit.

**Reconcile (pick one, prefer (a) — unblocks gate now):**

a. **Revert the crops-demo hunk** of 5858216 back to cad8614b, keep
   the other 6 input bumps (home-manager/iets/kin/llm-agents/maille/
   nixvim). Worker has cad8614b cached → eval passes again. Upstream
   repo no longer has cad8614b (force-recreated), so this is
   worker-local-cache-dependent — but so was the pre-5858216 state
   (see needs-human/bug-crops-demo-repo-not-found.md). Net: restores
   status quo ante.

   ```sh
   # surgical lock revert of one input:
   jq --argjson old "$(git show 5858216~1:flake.lock | jq '.nodes."crops-demo"')" \
      '.nodes."crops-demo" = $old' flake.lock > flake.lock.new
   mv flake.lock.new flake.lock
   nix eval .#nixosConfigurations.nv1.config.system.build.toplevel.outPath  # gate
   ```

b. Get 0182fa2c onto the worker: ask whoever has access (zimbatm
   fetched it) to `git -C /root/src/crops-demo fetch <their-remote>`
   or push the recreated repo somewhere the deploy key reaches, then
   `nix flake prefetch git+file:///root/src/crops-demo?rev=0182fa2c…`.
   Needs-human (no fetch path from here).

c. Re-grant deploy-key access to the recreated assise/crops-demo —
   the real fix. Already tracked in
   needs-human/bug-crops-demo-repo-not-found.md (updated this round).

**Blockers:** none for (a). Don't add a `.claude/` prefetch shim — see
tried/bug-crops-demo-repo-not-found.md (denylist).
