{ pkgs, ... }:
let
  py = pkgs.python3.withPackages (ps: [
    ps.openvino
    ps.transformers
    ps.soundfile
    ps.numpy
    ps.huggingface-hub
  ]);
  whisper-base-en-ov = pkgs.fetchgit {
    url = "https://huggingface.co/OpenVINO/whisper-base.en-fp16-ov";
    rev = "50b74f57c2339aaf6cd2bfae1e7a0a437d73faff";
    fetchLFS = true;
    hash = "sha256-iA220hJxoBLNJMQFucCGLygJgtCIlLftMqINFpaeOnQ=";
  };
in
pkgs.writeShellApplication {
  name = "transcribe-npu";
  runtimeInputs = [
    py
    pkgs.coreutils
  ];
  text = ''
    # Whisper on the Meteor Lake NPU via OpenVINO runtime. Frees the Arc iGPU
    # for ask-local so dictation + local-LLM run concurrently. ptt-dictate
    # prefers this path when /dev/accel/accel0 exists; also the first real
    # workload for `infer-queue add --lane npu -- transcribe-npu <wav>`.
    #   transcribe-npu <wav>   → prints transcript to stdout
    # Model: OpenVINO/whisper-base.en-fp16-ov, shipped as a FOD in the closure.
    MODEL="''${TRANSCRIBE_NPU_MODEL:-${whisper-base-en-ov}}"
    DEVICE="''${TRANSCRIBE_NPU_DEVICE:-NPU}"

    [[ -f "$MODEL/openvino_encoder_model.xml" ]] || { echo "transcribe-npu: model not found: $MODEL" >&2; exit 1; }

    exec python3 - "$MODEL" "$DEVICE" "''${1:-/dev/stdin}" <<'PY'
    import sys, numpy as np, soundfile as sf, openvino as ov
    from transformers import WhisperProcessor

    model_dir, device, wav = sys.argv[1], sys.argv[2], sys.argv[3]
    audio, _ = sf.read(wav, dtype="float32")
    if audio.ndim > 1: audio = audio.mean(axis=1)

    proc = WhisperProcessor.from_pretrained(model_dir)
    feat = proc(audio, sampling_rate=16000, return_tensors="np").input_features

    core = ov.Core()
    enc = core.compile_model(f"{model_dir}/openvino_encoder_model.xml", device)
    dec = core.compile_model(f"{model_dir}/openvino_decoder_model.xml", device)
    hidden = enc({enc.inputs[0].any_name: feat})[enc.outputs[0]]

    tok = proc.tokenizer
    ids = [tok.convert_tokens_to_ids(t) for t in ("<|startoftranscript|>", "<|notimestamps|>")]
    eos = tok.eos_token_id
    for _ in range(224):
        inp = {}
        for port in dec.inputs:
            n = port.any_name
            if "input_ids" in n: inp[n] = np.array([ids], dtype=np.int64)
            elif "hidden" in n:  inp[n] = hidden
            elif "mask" in n:    inp[n] = np.ones((1, len(ids)), dtype=np.int64)
        nxt = int(dec(inp)[dec.outputs[0]][0, -1].argmax())
        ids.append(nxt)
        if nxt == eos: break
    print(tok.decode(ids, skip_special_tokens=True).strip())
    PY
  '';
}
