{ pkgs, ... }:
# GNOME-portal screenshot + perceptual diff. nv1-native visual gate for desktop
# config — eval+dry-build proves it *evaluates*, gsnap --diff proves it *looks*
# right. agent-eyes `peek` uses grim which is wlroots-only and does NOT work on
# GNOME/Mutter; gsnap talks to org.gnome.Shell.Screenshot over the session bus
# instead. Leave peek alone — this is the nv1 path, not a replacement.
pkgs.writeShellApplication {
  name = "gsnap";
  runtimeInputs = [
    pkgs.glib
    pkgs.imagemagick
    pkgs.gawk
    pkgs.coreutils
  ];
  text = ''
    outdir=/tmp/gsnap
    mkdir -p "$outdir"
    last="$outdir/last.png"

    die() { echo "gsnap: $*" >&2; exit 1; }

    portal() {
      # portal <Method> <bool-args...> — writes downscaled PNG to $last
      local raw reply
      raw=$(mktemp --suffix=.png)
      if ! reply=$(gdbus call --session \
            --dest org.gnome.Shell.Screenshot \
            --object-path /org/gnome/Shell/Screenshot \
            --method "org.gnome.Shell.Screenshot.$1" "''${@:2}" "$raw" 2>&1); then
        rm -f "$raw"
        die "portal call failed (locked screen / no GNOME session?): $reply"
      fi
      [[ "$reply" == \(true,* ]] || { rm -f "$raw"; die "screenshot refused: $reply"; }
      magick "$raw" -resize 800x "$last"
      rm -f "$raw"
    }

    case "''${1:-}" in
      ""|--full)
        portal Screenshot false false        # include_cursor flash
        echo "$last"
        ;;
      --window)
        portal ScreenshotWindow true false false   # include_frame include_cursor flash (focused window)
        echo "$last"
        ;;
      --diff)
        baseline="''${2:?--diff needs a baseline path}"
        [[ -f "$baseline" ]] || die "baseline not found: $baseline"
        [[ -f "$last" ]] || portal Screenshot false false
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
        cat <<-EOF
    		gsnap                  full screen -> /tmp/gsnap/last.png (~800px wide)
    		gsnap --window         focused window -> /tmp/gsnap/last.png
    		gsnap --diff BASELINE  capture if needed, then perceptual diff; exit 1 if >5% pixels changed
    		EOF
        ;;
      *)
        die "unknown arg: $1 (try --help)"
        ;;
    esac
  '';
}
