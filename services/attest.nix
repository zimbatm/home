{
  optionsType = { lib, ... }: lib.types.submodule {
    options = {
      logPort = lib.mkOption { type = lib.types.port; default = 7480; };
      keyName = lib.mkOption { type = lib.types.str; default = "attest.ztm-1"; };
      stateDir = lib.mkOption { type = lib.types.str; default = "/var/lib/iets-attest"; };
      # iets flake's `packages.${system}.iets` (provides `ietsd`). Left null
      # until ietsd grows `attest-log {serve,publish}` subcommands — the
      # AttestationLogService server and sign_attestation are library-only
      # at iets@5faa622 (see ../iets/backlog/feat-attest-log-cli.md). The
      # gen key + publishes contract land now so consumers can name
      # `fleet.siblings.attest.publishes.{port,publicKey}` and `kin gen`
      # mints the builder identity ahead of the CLI shipping.
      package = lib.mkOption { type = lib.types.nullOr lib.types.package; default = null; };
    };
  };

  eval = { lib, pkgs, cfg, fleet }:
    let
      members = fleet._resolve cfg.on;
      # NAME:base64(raw 32-byte ed25519 pubkey) — the format
      # `ietsd substitute-proxy --trusted-key` parses (subst/proxy.rs
      # parse_trusted_key). Same typed-accessor shape kin-infra's services/ci.nix
      # uses for cache: consumers read fleet.siblings.attest.publishes.publicKey.
      # Inlined genPublic-with-null-fallback instead of `fleet.genPublic`:
      # `kin gen` JSON-forces kinManifest.services.*.publishes, so a hard
      # throw on the first run (before gen/attest/ exists) deadlocks
      # bootstrap — see ../kin/backlog/bug-gen-bootstrap-forces-publishes.md.
      pubFile = ../gen/attest/signing-key/_shared/public;
      publicKey =
        if builtins.pathExists pubFile
        then lib.removeSuffix "\n" (builtins.readFile pubFile)
        else null;
    in
    {
      # serverCert=false: the log is an untrusted append-only relay
      # (attestation.proto §AttestationLogService — trust is entirely
      # client-side via verify_attestations), so a kin-identity TLS cert
      # adds nothing. port published so consumers derive
      # `grpc://[${machineIp6 host}]:${publishes.port}` for --attest-log.
      publishes = {
        port = cfg.logPort;
        inherit publicKey;
        serverCert = false;
        statePaths = [ cfg.stateDir ];
      };

      gen.signing-key = {
        for = cfg.on;
        perMachine = false;
        inputs = [ pkgs.openssl ];
        # iets_castore::attest::load_signing_key wants a raw 32-byte seed
        # ("head -c32 /dev/urandom > builder.key"), not PEM. Generate via
        # openssl so the pubkey is derivable in the same script, then strip
        # the PKCS#8 DER header (16 bytes) to the bare seed.
        script = ''
          openssl genpkey -algorithm ed25519 -out pem
          openssl pkey -in pem -outform DER | tail -c32 > $out/key
          printf '%s:%s\n' ${lib.escapeShellArg cfg.keyName} \
            "$(openssl pkey -in pem -pubout -outform DER | tail -c32 | base64 -w0)" \
            > $out/public
        '';
        files.key.secret = true;
        files.public.secret = false;
      };

      nixos = { machineName, machine, genAccess }:
        lib.optional (members ? ${machineName}) ({ config, pkgs, ... }:
          let key = genAccess."attest/signing-key".key; in
          lib.mkMerge [
            { networking.firewall.interfaces.kinq0.allowedTCPPorts = [ cfg.logPort ]; }
            (lib.mkIf (cfg.package != null) {
              systemd.services.iets-attest-log = {
                description = "iets AttestationLogService (gRPC, append-only)";
                wantedBy = [ "multi-user.target" ];
                after = [ "network.target" ];
                serviceConfig = {
                  ExecStart = "${cfg.package}/bin/ietsd attest-log serve "
                    + "--listen [::]:${toString cfg.logPort} --state-dir ${cfg.stateDir}";
                  StateDirectory = baseNameOf cfg.stateDir;
                  DynamicUser = true;
                  Restart = "on-failure";
                };
              };
              # nix invokes post-build-hook with DRV_PATH + OUT_PATHS in env.
              # `attest-log publish` is responsible for resolving drv_hash to
              # the *resolved*-drv 20-byte store-path hash (attestation.proto
              # is explicit that signing the unresolved hash is unsound) and
              # extracting each CA output_hash, then sign_attestation +
              # Append to the local log.
              nix.settings.post-build-hook = toString (pkgs.writeShellScript "kin-attest-publish" ''
                exec ${cfg.package}/bin/ietsd attest-log publish \
                  --key "''${CREDENTIALS_DIRECTORY:-/run/credentials/nix-daemon.service}/builder-key" \
                  --log grpc://[::1]:${toString cfg.logPort} \
                  --drv "$DRV_PATH" $OUT_PATHS
              '');
              # Hook runs as a child of nix-daemon; deliver the raw seed via
              # LoadCredential so it never touches disk world-readable.
              systemd.services.nix-daemon = {
                after = [ "kin-secrets.service" ];
                wants = [ "kin-secrets.service" ];
                serviceConfig.LoadCredential = [ "builder-key:${key}" ];
              };
            })
          ]);
    };
}
