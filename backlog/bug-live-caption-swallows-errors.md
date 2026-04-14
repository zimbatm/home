# bug: live-caption-log swallows all errors — undiagnosable when output stays empty

## What

`packages/live-caption-log/default.nix` redirects every failure path to
`/dev/null`:

- `:50` `pw-record ... 2>/dev/null`
- `:57` `exec '$TNPU' '$prev' >'$out' 2>/dev/null` (inside infer-queue job)
- `:59` `infer-queue wait ... >/dev/null 2>&1 || true`
- `:61` inline fallback `"$TNPU" "$prev" >"$out" 2>/dev/null || true`

So when `~/.local/state/live-caption/` stays empty (observed 2026-04-14:
service running 55 min, chunks recording, zero jsonl), there is no way
to tell whether it's silence (expected) or transcribe-npu/infer-queue
failure (bug). `journalctl --user -u live-caption-log` shows nothing.

## Fix

1. Drop the `2>/dev/null` on transcribe-npu invocations — let stderr
   reach the journal. pw-record's stderr can stay suppressed (it's
   chatty about xruns).
2. Log a structured line on each chunk regardless of outcome:
   ```sh
   printf '%s chunk=%d bytes=%d text_len=%d queue=%s\n' \
     "$(date -u +%FT%TZ)" "$n" "$(stat -c%s "$prev")" "${#text}" "${job:-inline}" >&2
   ```
   so the journal shows the loop is alive and which step yielded zero.
3. On first successful non-empty write, emit one `notify-send -u low
   "live-caption: first transcript landed"` so the user knows it's
   working without tailing.
4. Track empty-chunk streak; after N consecutive (e.g. 60 ≈ 8 min) with
   non-silent input bytes, log a single warning — distinguishes
   "silence" from "transcribe-npu broken".

## How much

~0.2r. Mostly removing redirects + one printf. The streak counter is
~6 lines.

## Blockers

None. Runtime test gated on nv1 deploy + actual audio.
