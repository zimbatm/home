# ops: capture nv1 gsnap baseline

**needs-human** — runs on the live nv1 session.

## What

After `gsnap` lands on nv1 (next `kin deploy nv1`), capture the first
reference screenshot and commit it:

```sh
# on nv1, session unlocked, desktop in its "normal" state
gsnap
cp /tmp/gsnap/last.png ~/src/home/machines/nv1/baseline.png
cd ~/src/home && git add machines/nv1/baseline.png && git commit -m "nv1: gsnap baseline"
```

## Why

`gsnap --diff machines/nv1/baseline.png` is the second gate for desktop
changes (see `.claude/skills/gsnap/SKILL.md`). It needs a committed
reference to diff against; the agent can't capture one because it has no
unlocked GNOME session.

## Done when

`machines/nv1/baseline.png` exists on main and
`gsnap --diff machines/nv1/baseline.png` on a quiet desktop reports <5%.
