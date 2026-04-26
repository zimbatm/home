# adopt: NVIDIA NIM via Anthropic-shaped llm adapter

## what

Dogfood NVIDIA's hosted NIM/OpenAI-compatible API as a kin-managed LLM backend for nv1/home agents, without teaching every consumer a new provider shape.

Use a home-local `extraServices.llm-nvidia-adapter` wrapping LiteLLM:

```
NVIDIA NIM OpenAI-compatible API
  https://integrate.api.nvidia.com/v1/chat/completions
        ↓
LiteLLM proxy on nv1, mesh-only
        ↓
Anthropic-compatible /v1/messages
        ↓
kin services.grind.llm = "llm-nvidia-adapter"
```

Publish the adapter as:

```nix
publishes = {
  host = "nv1";
  port = 4000;
  apiShape = "anthropic";
  model = "claude-nvidia";
  route = null;
  serverCert = false;
};
```

LiteLLM route sketch:

```yaml
litellm_settings:
  drop_params: true
  num_retries: 0
  request_timeout: 120

model_list:
  - model_name: claude-nvidia
    litellm_params:
      model: openai/minimaxai/minimax-m2.7
      api_base: https://integrate.api.nvidia.com/v1
      api_key: os.environ/NVIDIA_API_KEY
```

## why

NVIDIA offers free/cheap hosted access to OpenAI-shaped models such as MiniMax, GLM, Kimi, DeepSeek, GPT-OSS, etc. This is useful as a cloud fallback for grind/agent workloads and as the second dogfood case for kin's pending generic `llm-adapter` lift.

Kin already has the consumer contract: `services.grind.llm` accepts a sibling or literal URL, but requires `publishes.apiShape = "anthropic"` because Claude Code speaks `/v1/messages`. NVIDIA is OpenAI-shaped (`/v1/chat/completions`), so direct `services.grind.llm = "https://integrate.api.nvidia.com/v1"` would not work. An adapter is the right seam.

## how

1. Rotate the NVIDIA key that was pasted into chat; treat it as compromised.
2. Add a home-local extra service, likely copied/adapted from `../kin-infra/services/llm-adapter.nix`, but route to NVIDIA instead of Ollama.
3. Store the API key as an external kin gen secret, not in git:

   ```nix
   gen."llm-nvidia/api-key" = {
     for = [ "nv1" ];
     files.key = {
       secret = true;
       external = true;
     };
   };
   ```

   Human action:

   ```sh
   kin set llm-nvidia/api-key/_shared/key
   ```

4. The adapter unit should use `LoadCredential` and export:

   ```sh
   NVIDIA_API_KEY="$(cat "$CREDENTIALS_DIRECTORY/nvidia-api-key")"
   ```

5. Point a low-risk consumer at it first. Options:
   - manual `curl`/Claude Code probe from nv1;
   - then `services.grind.llm = "llm-nvidia-adapter"` once it responds.

6. If this passes, cross-file to `../kin` that home is now N=2 for the generic `services/llm-adapter.nix` lift tracked in `../kin/backlog/needs-human/feat-services-llm-adapter.md`.

## acceptance

- `kin gen --check` passes.
- Adapter unit evaluates for nv1 and does not embed the API key in the Nix store.
- From nv1, `curl http://[nv1-mesh-ula]:4000/v1/messages` or equivalent LiteLLM Anthropic probe returns a model response using `claude-nvidia`.
- `services.grind.llm = "llm-nvidia-adapter"` eval passes the `apiShape = "anthropic"` assertion.
- A small grind/agent prompt reaches NVIDIA and logs a successful response.

## blockers / cautions

- Requires human to rotate and set the NVIDIA key.
- Do not run `kin deploy`; deploy is human-gated in this repo.
- LiteLLM packaging details should follow the working kin-infra adapter (`python3.withPackages`, proxy extras).
- NVIDIA quotas/rate limits/model availability may change; this is an experiment, not a hard dependency.
