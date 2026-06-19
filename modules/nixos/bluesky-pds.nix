{
  config,
  lib,
  pkgs,
  ...
}:
let
  domain = "pds.zimbatm.com";
  cfg = config.services.bluesky-pds;
in
{
  # Self-hosted AT Protocol PDS — holds zimbatm's bsky repo + blobs on our own
  # box (did:plc:wxnofyouho6vcuevbvocutid, handle @zimbatm.com). Federates into
  # the main Bluesky network via the default relay/AppView. The account was
  # migrated here from bsky.social; the DID and the _atproto.zimbatm.com TXT
  # record are unchanged — only the PDS endpoint + keys in the DID doc moved.
  # See docs/runbooks/bluesky-pds.md.
  services.bluesky-pds = {
    enable = true;
    # pdsadmin: create invite codes / manage accounts. goat: the migration CLI.
    pdsadmin.enable = true;
    settings = {
      PDS_HOSTNAME = domain;
      PDS_PORT = 3000;
      # Sender for confirmation / password-reset / PLC-operation emails. The
      # SMTP URL (with the Fastmail app password) is a secret and lives in the
      # environment file below, not here in the world-readable store.
      PDS_EMAIL_FROM_ADDRESS = "zimbatm@zimbatm.com";
    };
    # PDS_JWT_SECRET, PDS_ADMIN_PASSWORD, PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX
    # and PDS_EMAIL_SMTP_URL. Migrated agenix -> clan vars (imported, NOT
    # regenerated — the PLC rotation key is the PDS's identity).
    environmentFiles = [ config.clan.core.vars.generators.web2-bluesky-pds.files.value.path ];
  };

  clan.core.vars.generators.web2-bluesky-pds = {
    files.value.secret = true;
    prompts.value = {
      description = "Bluesky PDS env file (PDS_JWT_SECRET, PDS_ADMIN_PASSWORD, PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX, PDS_EMAIL_SMTP_URL)";
      type = "multiline-hidden";
      persist = true;
    };
    runtimeInputs = [ pkgs.coreutils ];
    script = ''cat "$prompts"/value > "$out"/value'';
  };

  services.nginx.virtualHosts."${domain}" = {
    enableACME = true;
    forceSSL = true;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString cfg.settings.PDS_PORT}";
      # Firehose (com.atproto.sync.subscribeRepos) is a long-lived WebSocket.
      proxyWebsockets = true;
      extraConfig = ''
        # Match PDS_BLOB_UPLOAD_LIMIT (100 MiB) so image/blob uploads aren't
        # truncated by nginx's 1 MB default.
        client_max_body_size 100m;
        # Keep the firehose socket open well past nginx's 60s default.
        proxy_read_timeout 12h;
        proxy_send_timeout 12h;
      '';
    };
  };
}
