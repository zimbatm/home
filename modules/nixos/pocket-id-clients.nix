{ config, lib, pkgs, ... }:
let
  cfg = config.services.pocketIdClients;

  # JSON spec consumed by the reconciler. Keyed by client id (which is
  # the slug used in URLs + the directory name under /run/pocket-id-clients).
  specFile = pkgs.writeText "pocket-id-clients.json" (builtins.toJSON cfg.clients);

  reconciler = pkgs.writeShellApplication {
    name = "pocket-id-clients-reconcile";
    runtimeInputs = [ pkgs.curl pkgs.jq ];
    text = ''
      set -euo pipefail
      API="${cfg.apiBaseUrl}"
      KEY="$(cat "$CREDENTIALS_DIRECTORY/api-key")"
      AUTH=(-H "X-API-Key: $KEY")
      SPEC=${specFile}

      # Wait for pocket-id (STATIC_API_KEY admin user is created lazily
      # on first API hit, so we just retry until /healthz says ok).
      tries=0
      until curl -sS -f -o /dev/null "$API/../healthz"; do
        tries=$((tries + 1))
        [ "$tries" -ge 60 ] && { echo "pocket-id not ready after 60s" >&2; exit 1; }
        sleep 1
      done

      mkdir -p /run/pocket-id-clients

      jq -r 'keys[]' "$SPEC" | while read -r id; do
        spec=$(jq --arg id "$id" '.[$id] + {id: $id}' "$SPEC")
        existing_status=$(curl -sS -o /dev/null -w '%{http_code}' "''${AUTH[@]}" "$API/oidc/clients/$id")
        if [ "$existing_status" = "200" ]; then
          echo "[$id] update"
          curl -sS -f -X PUT "''${AUTH[@]}" -H 'Content-Type: application/json' \
            -d "$spec" "$API/oidc/clients/$id" >/dev/null
        else
          echo "[$id] create"
          curl -sS -f -X POST "''${AUTH[@]}" -H 'Content-Type: application/json' \
            -d "$spec" "$API/oidc/clients" >/dev/null
        fi

        # Ensure /run/pocket-id-clients/<id> with {id, secret}. We only
        # generate a new secret when none exists on disk — rotating is
        # an explicit op (delete the secret file + restart this unit).
        mkdir -p "/run/pocket-id-clients/$id"
        echo -n "$id" > "/run/pocket-id-clients/$id/id"
        if [ ! -s "/run/pocket-id-clients/$id/secret" ]; then
          secret=$(curl -sS -f -X POST "''${AUTH[@]}" "$API/oidc/clients/$id/secret" | jq -r '.secret')
          if [ -z "$secret" ] || [ "$secret" = "null" ]; then
            echo "[$id] WARNING: secret generation returned empty payload" >&2
          else
            install -m 0640 /dev/null "/run/pocket-id-clients/$id/secret"
            echo -n "$secret" > "/run/pocket-id-clients/$id/secret"
          fi
        fi
        chmod 0640 "/run/pocket-id-clients/$id/secret" 2>/dev/null || true
      done
    '';
  };
in
{
  options.services.pocketIdClients = {
    apiBaseUrl = lib.mkOption {
      type = lib.types.str;
      example = "https://id.zimbatm.com/api";
      description = "Pocket ID's API base URL (no trailing slash).";
    };

    apiKeyFile = lib.mkOption {
      type = lib.types.path;
      description = "File containing the STATIC_API_KEY (passed via LoadCredential).";
    };

    credentialsGroup = lib.mkOption {
      type = lib.types.str;
      default = "pocket-id-clients";
      description = ''
        Group that owns /run/pocket-id-clients/<id>/secret. Downstream
        consumers should be in this group to read their client secret.
      '';
    };

    clients = lib.mkOption {
      default = { };
      description = ''
        Attribute set keyed by client id. Each value is the Pocket ID
        OIDC client spec as it appears in POST/PUT /api/oidc/clients —
        only `name` and `callbackURLs` are typically required.
      '';
      type = lib.types.attrsOf (
        lib.types.submodule {
          freeformType = (pkgs.formats.json { }).type;
          options = {
            name = lib.mkOption {
              type = lib.types.str;
              description = "Display name in the Pocket ID admin UI.";
            };
            callbackURLs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              description = "OAuth2 redirect URIs (exact match unless using `*` wildcard).";
            };
            logoutCallbackURLs = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [ ];
            };
            pkceEnabled = lib.mkOption {
              type = lib.types.bool;
              default = true;
            };
            isPublic = lib.mkOption {
              type = lib.types.bool;
              default = false;
              description = "Public client (no secret) — typical for SPAs / mobile.";
            };
            requiresReauthentication = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
          };
        }
      );
    };
  };

  config = lib.mkIf (cfg.clients != { }) {
    users.groups.${cfg.credentialsGroup} = { };

    systemd.services.pocket-id-clients = {
      description = "Reconcile Pocket ID OIDC clients against Nix-declared spec";
      # agenix-install-secrets populates /run/agenix/* — the LoadCredential
      # below would fail at activation time if we don't wait for it.
      after = [ "pocket-id.service" "network-online.target" "agenix-install-secrets.service" ];
      wants = [ "pocket-id.service" "network-online.target" ];
      requires = [ "agenix-install-secrets.service" ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ specFile ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = lib.getExe reconciler;
        LoadCredential = "api-key:${cfg.apiKeyFile}";
        RuntimeDirectory = "pocket-id-clients";
        RuntimeDirectoryMode = "0755";
        RuntimeDirectoryPreserve = true;
        Group = cfg.credentialsGroup;
        UMask = "0027";
      };
    };
  };
}
