{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "infer-queue";
  runtimeInputs = [
    pkgs.pueue
    pkgs.coreutils
  ];
  text = ''
    # Device-tagged background job queue for nv1 local inference. Thin wrapper
    # over pueue with one group per compute lane (arc iGPU, npu Meteor Lake,
    # cpu) and a 1-slot limit on the accelerator lanes so concurrent jobs
    # don't thrash the device. Agents submit and poll instead of blocking.
    #
    #   infer-queue add --lane <arc|npu|cpu> -- <cmd...>
    #   infer-queue status
    #   infer-queue log <id>
    #   infer-queue wait <id>

    usage() {
      echo "usage: infer-queue add --lane <arc|npu|cpu> -- <cmd...>" >&2
      echo "       infer-queue status | log <id> | wait <id>" >&2
      exit 1
    }

    ensure_lanes() {
      # Groups live in pueued state, not config — (re)assert on every add.
      for g in arc npu cpu; do pueue group add "$g" >/dev/null 2>&1 || true; done
      pueue parallel 1 -g arc >/dev/null
      pueue parallel 1 -g npu >/dev/null
      pueue parallel 4 -g cpu >/dev/null
    }

    cmd="''${1:-}"; [[ $# -gt 0 ]] && shift
    case "$cmd" in
      add)
        [[ "''${1:-}" == "--lane" ]] || usage
        lane="''${2:-}"; shift 2 || usage
        case "$lane" in arc|npu|cpu) ;; *)
          echo "infer-queue: lane must be one of: arc npu cpu" >&2; exit 1 ;;
        esac
        [[ "''${1:-}" == "--" ]] && shift
        [[ $# -gt 0 ]] || usage
        ensure_lanes
        exec pueue add -g "$lane" -- "$@"
        ;;
      status) exec pueue status "$@" ;;
      log)    exec pueue log "$@" ;;
      wait)   exec pueue wait "$@" ;;
      *)      usage ;;
    esac
  '';
}
