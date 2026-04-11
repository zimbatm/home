---
name: infer-queue
description: Submit local-inference work on nv1 to a device-tagged background queue instead of running it inline. Use for any whisper/llama/OpenVINO job expected to take more than ~5s — submit, keep working, poll later.
---

nv1's host-side compute is the Intel Arc iGPU and the Meteor Lake NPU (the
RTX 4060 is vfio-bound). `infer-queue` is a thin pueue wrapper with one
group per lane and a single slot on each accelerator so jobs serialize
instead of fighting over the device.

```sh
infer-queue add --lane arc -- whisper-cpp -m ~/.local/share/whisper/ggml-base.en.bin rec.wav
infer-queue add --lane cpu -- ask-local "summarise $(cat notes.md)"
infer-queue status          # table of queued/running/done
infer-queue log <id>        # stdout/stderr of a task
infer-queue wait <id>       # block until <id> finishes (use sparingly)
```

Lanes: `arc` (1 slot, Vulkan/oneAPI on the iGPU), `npu` (1 slot — defined
but **no consumers yet**; the OpenVINO-whisper exploration hasn't landed a
runnable binary), `cpu` (4 slots).

Don't block the conversation on inference: `add`, note the id, carry on,
then check `status`/`log` in a later turn.
