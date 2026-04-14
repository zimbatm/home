{ pkgs, ... }:
let
  py = pkgs.python3.withPackages (ps: [
    ps.openvino
    ps.numpy
  ]);
  ptt-dictate = pkgs.callPackage ../ptt-dictate { };
  # Silero VAD v4.0 — v5.x ONNX has an If-based 8k/16k branch with dynamic-rank
  # Conv/ReduceMean that OpenVINO 2026.1's ONNX frontend cannot convert
  # (OpConversionFailure on Conv-16/ReduceMean-16). v4 compiles clean.
  silero-vad = pkgs.fetchurl {
    url = "https://github.com/snakers4/silero-vad/raw/v4.0/files/silero_vad.onnx";
    hash = "sha256-o16/Uv085fFGmyo2FY26dhvEe5c+ozgrMYbKFbH1ryg=";
  };
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
    # Model: Silero VAD v4 ONNX (~1.8 MB), shipped as a FOD in the closure.
    MODEL="''${WAKE_LISTEN_MODEL:-${silero-vad}}"
    DEVICE="''${WAKE_LISTEN_DEVICE:-NPU}"
    RUNTIME="''${XDG_RUNTIME_DIR:-/tmp}/wake-listen"
    mkdir -p "$RUNTIME"

    ONESHOT=0
    [[ "''${1:-}" == "--oneshot" ]] && ONESHOT=1

    [[ -f "$MODEL" ]] || { echo "wake-listen: model not found: $MODEL" >&2; exit 1; }

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
    p_out, p_hn, p_cn = vad.outputs[0], vad.outputs[1], vad.outputs[2]

    rec = subprocess.Popen(
        ["pw-record", "--rate", "16000", "--channels", "1", "-"],
        stdout=subprocess.PIPE,
    )
    rec.stdout.read(44)  # canonical WAV header

    sr = np.array(16000, dtype=np.int64)
    h = np.zeros((2, 1, 64), dtype=np.float32)
    c = np.zeros((2, 1, 64), dtype=np.float32)
    streak = 0
    while True:
        raw = rec.stdout.read(CHUNK * 2)
        if len(raw) < CHUNK * 2:
            sys.exit(rec.wait())
        pcm = (np.frombuffer(raw, np.int16).astype(np.float32) / 32768.0)[None, :]
        res = vad({"input": pcm, "h": h, "c": c, "sr": sr})
        h, c = res[p_hn], res[p_cn]
        streak = streak + 1 if res[p_out].item() > THRESH else 0
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
        h = np.zeros((2, 1, 64), dtype=np.float32)
        c = np.zeros((2, 1, 64), dtype=np.float32)
        streak = 0
    PY
  '';
}
