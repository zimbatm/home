# simplify: live-caption.nix stale dangling ref to closed needs-human file

**what** — `modules/home/desktop/live-caption.nix:12-14` comment still says
"Enable per-host only after the privacy stance in
backlog/needs-human/ops-live-caption-privacy.md is decided." That file was
closed and deleted by 396d2de (Policy 2026-04-14: all audio, 30d retention,
`live-caption off` to pause). The comment now points at nothing.

**why** — doc-rot; future reader greps for the referenced file and finds
nothing. The "off by default" rationale is still true but the gating
condition it describes is past-tense.

**how-much** — 3L comment rewrite. Replace with the decided policy so the
default-off rationale stays but the dangling path goes:

```nix
  # Off by default — capturing the sink monitor turns *all* desktop audio into
  # text on disk. Policy 2026-04-14 (396d2de): enable per-host with explicit
  # retentionDays; `live-caption off` for per-session pause.
```

**blockers** — none. Comment-only; no eval/closure change. Gate: `nix fmt`
+ `kin gen --check` (trivially passes).
