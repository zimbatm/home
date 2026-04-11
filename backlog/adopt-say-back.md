# adopt-say-back — TTS half of the voice loop (piper → pipewire)

## what

`packages/say-back/` — `writeShellApplication` reading stdin, synthesising
with `piper-tts` (nixpkgs `piper-tts`, ONNX, CPU-real-time), playing via
`pw-play`. Same shape as `ptt-dictate`: model under
`$XDG_DATA_HOME/piper/`, print fetch hint if missing, degrade silently.

Optional wiring: a Claude Code `Stop` hook that, when the ghostty window
is *not* focused (cheap `gdbus call …Shell.Eval` active-window check),
pipes the first sentence of the last assistant message to `say-back`.
Dictate a prompt with Super+d, walk to the kettle, hear the answer.

## why

`ptt-dictate` landed speech→text on the Arc iGPU. The reverse leg is
missing, so "voice-first agent" is half a loop. piper is the obvious fit:
already packaged, ~60 MB voice model, runs faster-than-real-time on CPU —
deliberately *off* the Arc/NPU so it never contends with whisper or
ask-local. No survey source ships this pairing; Mic92's ai.nix has no
TTS. This is the original-work counterpart to ptt-dictate, not a copy.

## how much

~40 LoC package (`piper --model … --output-raw | pw-play --rate 22050
--channels 1 -`). ~15 LoC Stop hook (jq the newest `~/.claude/**/*.jsonl`
for last assistant text, head -c 200, pipe). Add to desktop hm packages;
hook goes in `modules/home/terminal` claude settings template.

## falsifies

Is a full dictate↔speak loop daily-driver viable on nv1, or does piper
latency/prosody break flow enough that Jonas mutes it in a week? Secondary:
does CPU-only TTS measurably steal from concurrent Arc whisper (agent-meter
should show ~0 Arc delta)?

## blockers

None. `piper-tts` in nixpkgs; pipewire already on nv1; Stop hooks already
exercised by agentshell SessionStart precedent (commit 2a6ea95).
