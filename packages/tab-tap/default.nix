{ pkgs, ... }:
let
  py = pkgs.python3;

  cli = pkgs.writeShellApplication {
    name = "tab-tap";
    runtimeInputs = [
      py
      pkgs.jq
    ];
    text = ''
      # Two verbs against the focused Firefox tab via the tab_tap native bridge.
      # The host process is Firefox-spawned (lives as long as the browser) and
      # owns $XDG_RUNTIME_DIR/tab-tap.sock; we are a thin one-shot client.
      #
      #   tab-tap read                       → {url,title,text}  (Readability extract)
      #   tab-tap act <css-selector> [text]  → click, or set value+input/change if text given
      #
      # Falsifies: do two verbs cover the 80% agent-browser case, or does the
      # loop immediately want arbitrary JS (→ just use Mic92/browser-cli)?

      sock="''${XDG_RUNTIME_DIR:-/tmp}/tab-tap.sock"
      [[ -S "$sock" ]] || {
        echo "tab-tap: socket $sock not found — is Firefox running with the tab-tap extension loaded?" >&2
        exit 1
      }

      case "''${1:-}" in
        read)
          req='{"op":"read"}'
          ;;
        act)
          [[ -n "''${2:-}" ]] || { echo "usage: tab-tap act <css-selector> [text]" >&2; exit 2; }
          req=$(jq -cn --arg s "$2" --arg t "''${3:-}" \
            'if $t=="" then {op:"act",selector:$s} else {op:"act",selector:$s,text:$t} end')
          ;;
        *)
          echo "usage: tab-tap read | tab-tap act <css-selector> [text]" >&2
          exit 2
          ;;
      esac

      exec python3 - "$sock" "$req" <<'PY'
      import json, socket, sys
      sock, req = sys.argv[1], sys.argv[2]
      s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
      s.settimeout(10)
      s.connect(sock)
      s.sendall((req + "\n").encode())
      print(s.makefile().readline(), end="")
      PY
    '';
  };
in
# One drv: bin/tab-tap, libexec/tab-tap-host, share/tab-tap/extension/.
# HM writes ~/.mozilla/native-messaging-hosts/tab_tap.json → libexec path;
# the extension itself is loaded as a temporary add-on (or via policies)
# from share/tab-tap/extension — no AMO, no signing, dogfood-local.
pkgs.runCommand "tab-tap"
  {
    nativeBuildInputs = [ pkgs.makeWrapper ];
    meta.mainProgram = "tab-tap";
  }
  ''
    install -Dm755 ${cli}/bin/tab-tap $out/bin/tab-tap
    install -Dm644 -t $out/share/tab-tap/extension \
      ${./extension/manifest.json} \
      ${./extension/background.js} \
      ${./extension/Readability.js}
    # rename: nix store paths are hash-prefixed, extension wants plain names
    for f in manifest.json background.js Readability.js; do
      mv $out/share/tab-tap/extension/*-$f $out/share/tab-tap/extension/$f
    done
    makeWrapper ${py}/bin/python3 $out/libexec/tab-tap-host \
      --add-flags ${./native-host.py}
  ''
