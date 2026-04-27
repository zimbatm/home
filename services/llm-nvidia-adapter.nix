# LiteLLM proxy for NVIDIA NIM. NVIDIA's hosted endpoint is OpenAI-shaped
# (/v1/chat/completions); kin services.grind / claude-code expect Anthropic
# (/v1/messages). This mesh-only adapter republishes the hosted model with
# publishes.apiShape="anthropic" so consumers can stay shape-checked.
{
  optionsType =
    { lib, ... }:
    lib.types.submodule {
      options = {
        port = lib.mkOption {
          type = lib.types.port;
          default = 4000;
        };
        model = lib.mkOption {
          type = lib.types.str;
          default = "claude-nvidia";
          description = "Local Anthropic-shaped model name exposed by LiteLLM.";
        };
        upstreamModel = lib.mkOption {
          type = lib.types.str;
          default = "minimaxai/minimax-m2.7";
          description = "NVIDIA NIM OpenAI-compatible model id.";
        };
        apiBase = lib.mkOption {
          type = lib.types.str;
          default = "https://integrate.api.nvidia.com/v1";
          description = "NVIDIA NIM OpenAI-compatible /v1 base URL.";
        };
      };
    };

  eval =
    {
      lib,
      pkgs,
      cfg,
      fleet,
    }:
    let
      members = fleet._resolve cfg.on;
      host = fleet.resolveOne "services.llm-nvidia-adapter.on" cfg.on;
    in
    {
      publishes = {
        inherit host;
        port = cfg.port;
        apiShape = "anthropic";
        model = cfg.model;
        route = null;
        serverCert = false;
        health = {
          path = "/health/liveliness";
          expectBody = "alive";
        };
      };

      gen.api-key.files.key = {
        secret = true;
        external = true;
      };

      nixos =
        { machineName, genAccess, ... }:
        lib.optional (members ? ${machineName}) (
          { pkgs, ... }:
          let
            litellmEnv = pkgs.python3.withPackages (
              ps:
              let
                litellmPkg = ps.litellm;
              in
              [ litellmPkg ] ++ litellmPkg.optional-dependencies.proxy
            );
            configYaml = pkgs.writeText "litellm-nvidia.yaml" (
              lib.generators.toYAML { } {
                litellm_settings = {
                  # claude-code may send Anthropic-specific params that the
                  # OpenAI/NVIDIA backend does not understand.
                  drop_params = true;
                  # Hosted quota/rate-limit failures should surface quickly;
                  # systemd handles process restart, not request retries.
                  num_retries = 0;
                  request_timeout = 120;
                };
                model_list = [
                  {
                    model_name = cfg.model;
                    litellm_params = {
                      model = "openai/${cfg.upstreamModel}";
                      api_base = cfg.apiBase;
                      api_key = "os.environ/NVIDIA_API_KEY";
                    };
                  }
                ];
              }
            );
            launcher = pkgs.writeShellApplication {
              name = "kin-llm-nvidia-adapter";
              text = ''
                NVIDIA_API_KEY="$(cat "$CREDENTIALS_DIRECTORY/nvidia-api-key")"
                export NVIDIA_API_KEY
                exec ${litellmEnv}/bin/litellm --config ${configYaml} --host :: --port ${toString cfg.port}
              '';
            };
          in
          {
            systemd.services.kin-llm-nvidia-adapter = {
              description = "LiteLLM proxy — Anthropic-shape front for NVIDIA NIM";
              wantedBy = [ "multi-user.target" ];
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              # LiteLLM's Anthropic adapter checks this even though our route
              # dispatches to NVIDIA via OpenAI-compatible credentials.
              environment.ANTHROPIC_API_KEY = "sk-local";
              serviceConfig = fleet.hardenedServiceConfig {
                ExecStart = "${launcher}/bin/kin-llm-nvidia-adapter";
                LoadCredential = [ "nvidia-api-key:${genAccess."llm-nvidia-adapter/api-key".key}" ];
                Restart = "on-failure";
                ProcSubset = "pid";
                ProtectProc = "invisible";
              };
            };
            networking.firewall.interfaces.kinq0.allowedTCPPorts = [ cfg.port ];
          }
        );
    };
}
