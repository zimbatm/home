{ pkgs, ... }:
let
  py = pkgs.python3.withPackages (ps: [
    ps.openvino
    ps.numpy
  ]);
  ptt-dictate = pkgs.callPackage ../ptt-dictate { };
in
pkgs.writeShellApplication {
  name = "wake-listen";
  runtimeInputs = [
    py
    ptt-dictate
    pkgs.pipewire
    pkgs.coreutils
  ];
  text = ''
    # Always-on Silero VAD on the Meteor Lake NPU. Reads a 16 kHz pipewire
    # monitor stream, infers speech-probability per 32 ms frame, and on a
    # debounced onset fires ptt-dictate. Keeps the Arc iGPU free for ask-local
    # and the CPU asleep — the NPU is the ambient coprocessor.
    #   wake-listen            → loop forever (systemd --user unit)
    #   wake-listen --oneshot  → exit 0 on first onset (testing)
    # Model: Silero VAD v5 ONNX (~1.8 MB) under XDG_DATA_HOME.
    MODEL="''${WAKE_LISTEN_MODEL:-''${XDG_DATA_HOME:-$HOME/.local/share}/openvino/silero_vad.onnx}"
    DEVICE="''${WAKE_LISTEN_DEVICE:-NPU}"
    RUNTIME="''${XDG_RUNTIME_DIR:-/tmp}/wake-listen"
    mkdir -p "$RUNTIME"

    ONESHOT=0
    [[ "''${1:-}" == "--oneshot" ]] && ONESHOT=1

    if [[ ! -f "$MODEL" ]]; then
      echo "wake-listen: model not found: $MODEL" >&2
      echo "  fetch: mkdir -p \"$(dirname "$MODEL")\" && \\" >&2
      echo "    curl -L -o \"$MODEL\" https://github.com/snakers4/silero-vad/raw/v5.1/src/silero_vad/data/silero_vad.onnx" >&2
      exit 1
    fi

    if [[ -f "$RUNTIME/active" ]] && kill -0 "$(cat "$RUNTIME/active" 2>/dev/null)" 2>/dev/null; then
      echo "wake-listen: already active (pid $(cat "$RUNTIME/active"))" >&2
      exit 0
    fi

    exec python3 - "$MODEL" "$DEVICE" "$ONESHOT" "$RUNTIME" <<'PY'
    import sys, os, signal, subprocess, numpy as np, openvino as ov

    model, device, oneshot, runtime = sys.argv[1:5]
    active = os.path.join(runtime, "active")
    THRESH, DEBOUNCE, CHUNK = 0.5, 5, 512  # 5 × 32 ms = 160 ms sustained speech

    core = ov.Core()
    vad = core.compile_model(model, device)
    p_out, p_state = vad.outputs[0], vad.outputs[1]

    rec = subprocess.Popen(
        ["pw-record", "--rate", "16000", "--channels", "1", "-"],
        stdout=subprocess.PIPE,
    )
    rec.stdout.read(44)  # canonical WAV header

    sr = np.array(16000, dtype=np.int64)
    state = np.zeros((2, 1, 128), dtype=np.float32)
    streak = 0
    while True:
        raw = rec.stdout.read(CHUNK * 2)
        if len(raw) < CHUNK * 2:
            sys.exit(rec.wait())
        pcm = (np.frombuffer(raw, np.int16).astype(np.float32) / 32768.0)[None, :]
        res = vad({"input": pcm, "state": state, "sr": sr})
        state = res[p_state]
        streak = streak + 1 if float(res[p_out]) > THRESH else 0
        if streak < DEBOUNCE or os.path.exists(active):
            continue
        if oneshot == "1":
            print("speech")
            sys.exit(0)
        with open(active, "w") as f:
            f.write(str(os.getpid()))
        try:
            rec.send_signal(signal.SIGSTOP)
            subprocess.run(["ptt-dictate"])
        finally:
            rec.send_signal(signal.SIGCONT)
            try: os.unlink(active)
            except OSError: pass
        state = np.zeros((2, 1, 128), dtype=np.float32)
        streak = 0
    PY
  '';
}
