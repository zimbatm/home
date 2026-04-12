# ops: live-caption-log privacy stance + enable

**needs-human** — policy decision, then per-host enable.

## What

`live-caption-log` (landed, off by default) taps the PipeWire **sink
monitor** — every sound the desktop plays (calls, videos, music, system
notifications) is whisper-transcribed on the NPU and appended as plain
text to `~/.local/state/live-caption/YYYY-MM-DD.jsonl`, then folded into
the `sem-grep` index nightly. Nothing leaves disk and no audio is kept,
but the text is a verbatim record of one side of every call.

Decide whether that's acceptable on nv1, and if so under what bounds
(retention? auto-prune after N days? exclude when certain apps are
focused?). Then flip it on:

```sh
# in machines/nv1/configuration.nix, inside the home-manager block:
home.live-caption.enable = true;
# review + kin deploy nv1 (see ../kin/docs/howto/lockout-recovery.md)
```

## Why

The backlog item flagged this as an explicit ops-* blocker: even though
it's local-only, "records all desktop audio to text" is a stance that
should be taken deliberately, not defaulted into by an agent. The module
ships disabled so the code path can be reviewed without exposure.

## Done when

- Privacy bounds written down (here or in machines/nv1/ comment).
- `home.live-caption.enable = true;` on nv1 and deployed.
- After ~30 min of audio: `agent-meter` NPU-busy % captured (falsifies
  the realtime-headroom claim in the original adopt item).
