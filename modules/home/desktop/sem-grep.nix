{
  pkgs,
  inputs,
  ...
}:
let
  self' = inputs.self.packages.${pkgs.stdenv.hostPlatform.system};
in
{
  # sem-grep on PATH (the hist-sem alias in ../terminal already assumes it).
  home.packages = [ self'.sem-grep ];

  # Nightly: last-7d journald (user + system≤warning) → hour-dedup → embed on
  # the NPU → sqlite `logs` table, so `sem-grep log "wake-listen crash"` works.
  # Falsifies whether bge-small embeds machine log text — bench at
  # packages/sem-grep/bench-log.txt, gated on ops-deploy-nv1.
  systemd.user.services.sem-grep-index-log = {
    Unit = {
      Description = "sem-grep: embed last-7d journald into the log index";
      ConditionPathExists = "/dev/accel/accel0";
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${self'.sem-grep}/bin/sem-grep index-log";
    };
  };
  systemd.user.timers.sem-grep-index-log = {
    Unit.Description = "Nightly sem-grep journald reindex";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
