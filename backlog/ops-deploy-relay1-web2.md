# relay1 + web2: redeploy (drifted again post-d2ad1d1)

**What:** `kin deploy relay1 web2` from a mesh-connected machine.

**Why:** Both were have==want @ d2ad1d1 (relay1 `dpxnfwvk`, web2
`zv4kapl1`). Bumper landed f2c38c8 (kin/iets/nix-skills/llm-agents
internal bump) and 821b625 (srvos bump) since; both closures moved.

`kin status --json` @ 589a2f5:
```
relay1: have dpxnfwvk… ≠ want cfp7bc9j…  (health=running, secrets=active, failed=-, uptime 6d1h)
web2:   have zv4kapl1… ≠ want d5x5xl4j…  (health=running, secrets=active, failed=-, uptime 6d4h)
```

**Closure attribution (bisect relay1 @ 7e93604 vs f2c38c8):**
- 1201785 gsnap, d00a686 IFD-ban, 6bf3705 kin.nix admin-drop —
  relay1-closure-neutral (relay1 still `dpxnfwvk` @ 7e93604)
- f2c38c8 kin/iets bump — relay1 `dpxnfwvk`→`cfp7bc9j` (the current
  want; sole relay1-affecting commit)
- 821b625 srvos bump — relay1-closure-neutral (`cfp7bc9j` unchanged);
  web2 not bisected, may contribute there alongside f2c38c8

**Reconcile:** just deploy. No declared-side gap (deployed has nothing
declared lacks — `have` matches the d2ad1d1 want exactly). web2
restic-backups-gotosocial timer runtime check from d2ad1d1 still
applies if not yet walked.

**Blockers:** Human-gated (CLAUDE.md). Low-risk: kin/iets lib bump +
srvos minor; same nixpkgs 4c1018d throughout.
