{ pkgs, ... }:
# Compositor-aware screenshot + perceptual diff. nv1-native visual gate for
# desktop config — eval+dry-build proves it *evaluates*, gsnap --diff proves it
# *looks* right.
#
# GNOME path: org.gnome.Shell.Screenshot is sender-restricted since GNOME 41
# (CLI callers get AccessDenied unconditionally — no allowlist for scripts), so
# we go through xdg-desktop-portal's async Request/Response instead.
# Non-interactive capture needs a one-time PermissionStore grant for app_id ""
# (host apps) — shipped as home.activation.grantScreenshotPortal in
# modules/home/desktop/default.nix.
#
# wlroots path (niri/sway/…): grim speaks wlr-screencopy directly. 1 line.
pkgs.writeShellApplication {
  name = "gsnap";
  runtimeInputs = [
    pkgs.glib
    pkgs.grim
    pkgs.imagemagick
    pkgs.gawk
    pkgs.gnugrep
    pkgs.gnused
    pkgs.coreutils
  ];
  text = ''
    outdir=/tmp/gsnap
    mkdir -p "$outdir"
    last="$outdir/last.png"
    desktop=$(printf '%s' "''${XDG_CURRENT_DESKTOP:-}" | tr '[:upper:]' '[:lower:]' | cut -d: -f1)

    die() { echo "gsnap: $*" >&2; exit 1; }

    capture() {
      # writes downscaled PNG to $last
      local raw
      raw=$(mktemp --suffix=.png)
      case "''${XDG_CURRENT_DESKTOP:-}" in
        niri|sway|*wlroots*|Hyprland)
          grim "$raw" || { rm -f "$raw"; die "grim failed (no wlr-screencopy?)"; }
          ;;
        GNOME|*)
          # xdg-desktop-portal Screenshot: call → Request handle → wait for
          # Response signal carrying the file:// URI. Start monitor first to
          # avoid the race; the handle_token makes the request path greppable.
          local token mon monpid reply line uri src
          token="gsnap$$x$RANDOM"
          mon=$(mktemp)
          gdbus monitor --session --dest org.freedesktop.portal.Desktop >"$mon" 2>/dev/null &
          monpid=$!
          sleep 0.1
          if ! reply=$(gdbus call --session \
                --dest org.freedesktop.portal.Desktop \
                --object-path /org/freedesktop/portal/desktop \
                --method org.freedesktop.portal.Screenshot.Screenshot \
                "" "{'handle_token': <'$token'>, 'interactive': <false>}" 2>&1); then
            kill "$monpid" 2>/dev/null || true; rm -f "$mon" "$raw"
            die "portal call failed (no session bus?): $reply"
          fi
          line=""
          for _ in $(seq 50); do
            line=$(grep "/$token: .*Request\.Response" "$mon" 2>/dev/null || true)
            [[ -n "$line" ]] && break
            sleep 0.1
          done
          kill "$monpid" 2>/dev/null || true; rm -f "$mon"
          [[ -n "$line" ]] || { rm -f "$raw"; die "portal timed out (locked screen?)"; }
          [[ "$line" == *"uint32 0"* ]] || { rm -f "$raw"; die "portal denied (PermissionStore grant missing? re-run home-manager activation)"; }
          uri=$(printf '%s' "$line" | sed -n "s|.*'file://\([^']*\)'.*|\1|p")
          [[ -n "$uri" ]] || { rm -f "$raw"; die "portal Response had no uri: $line"; }
          src=$(printf '%b' "''${uri//%/\\x}")
          mv "$src" "$raw"
          ;;
      esac
      magick "$raw" -resize 800x "$last"
      rm -f "$raw"
    }

    case "''${1:-}" in
      ""|--full)
        capture
        echo "$last"
        ;;
      --diff)
        baseline="''${2:-machines/nv1/baseline-''${desktop:-unknown}.png}"
        [[ -f "$baseline" ]] || die "baseline not found: $baseline"
        [[ -f "$last" ]] || capture
        total=$(magick identify -format '%[fx:w*h]' "$last")
        set +e
        ae=$(magick compare -metric AE -fuzz 5% "$baseline" "$last" null: 2>&1); rc=$?
        set -e
        [[ $rc -le 1 ]] || die "compare failed (size mismatch?): $ae"
        ae=''${ae%% *}
        pct=$(awk -v a="$ae" -v t="$total" 'BEGIN{printf "%.1f", (t>0? a/t*100 : 0)}')
        echo "pixel-delta: ''${pct}% (''${ae}/''${total} px, fuzz 5%)"
        awk -v p="$pct" 'BEGIN{exit (p > 5.0 ? 1 : 0)}'
        ;;
      -h|--help)
        printf '%s\n' \
          "gsnap                    full screen -> /tmp/gsnap/last.png (~800px wide)" \
          "gsnap --diff [BASELINE]  capture if needed, then perceptual diff; exit 1 if >5% pixels changed" \
          "                         (BASELINE defaults to machines/nv1/baseline-$desktop.png)"
        ;;
      *)
        die "unknown arg: $1 (try --help)"
        ;;
    esac
  '';
}
