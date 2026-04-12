{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "man-here";
  runtimeInputs = [
    pkgs.coreutils
    pkgs.findutils
    pkgs.gnugrep
    pkgs.gnused
    pkgs.gawk
    pkgs.man
    pkgs.util-linux # col
    pkgs.nix
    pkgs.jq
    pkgs.nix-index # nix-locate (db via nix-index-database hm module)
  ];
  text = ''
    # Version-exact docs assembled from /nix/store. Resolves <cmd> to its
    # installed store output and emits markdown: package id + meta.description
    # (via pinned <nixpkgs> — modules/nixos/pin-nixpkgs.nix), rendered man
    # page, capped --help, and $out/share/doc README*. Every section degrades
    # gracefully; nothing past arg-parse is fatal.
    #
    # Not in PATH → nix-locate fallback names the providing attr (db from the
    # nix-index-database input already wired in modules/home/terminal).
    #
    #   man-here jq          → markdown to stdout
    #   man-here --raw jq    → uncapped (full man page)

    raw=0
    [[ "''${1:-}" == "--raw" ]] && { raw=1; shift; }
    [[ $# -ge 1 ]] || { echo "usage: man-here [--raw] <cmd>" >&2; exit 2; }
    cmd="$1"

    hdr() { printf '\n## %s\n\n' "$1"; }
    # awk reads to EOF → no SIGPIPE under pipefail (unlike head -n).
    cap() { if [[ $raw -eq 1 ]]; then cat; else awk -v n="$1" 'NR<=n'; fi; }

    real=""; out=""; pname=""
    if bin=$(command -v -- "$cmd" 2>/dev/null); then
      real=$(readlink -f "$bin")
      out=$(grep -oE '^/nix/store/[^/]+' <<<"$real" || true)
    fi

    if [[ -n "$out" ]]; then
      drv=$(nix-store -q --deriver "$out" 2>/dev/null || true)
      if [[ -n "$drv" && "$drv" != "unknown-deriver" && -e "$drv" ]]; then
        pname=$(nix derivation show "$drv^*" 2>/dev/null \
          | jq -r 'first(.[]).env.pname // empty' 2>/dev/null || true)
      fi
      [[ -n "$pname" ]] \
        || pname=$(basename "$out" | sed -E 's/^[a-z0-9]{32}-//; s/-[0-9].*$//')
    fi

    printf '# %s\n' "$cmd"

    hdr "package"
    if [[ -n "$out" ]]; then
      echo "- store: \`$out\`"
      echo "- bin:   \`$real\`"
      [[ -z "$pname" ]] || echo "- pname: \`$pname\`"
      # Best-effort: wrapped/local pkgs won't resolve in <nixpkgs>.
      if [[ -n "$pname" ]]; then
        desc=$(nix-instantiate --eval --json -E \
          "(import <nixpkgs> {}).\"$pname\".meta.description or \"\"" \
          2>/dev/null | jq -r . 2>/dev/null || true)
        [[ -z "$desc" ]] || echo "- desc:  $desc"
      fi
    elif command -v nix-locate >/dev/null; then
      echo "(not in PATH — nix-locate providers for bin/$cmd:)"
      echo '```'
      loc=$(nix-locate --top-level --minimal --at-root --whole-name "/bin/$cmd" 2>/dev/null || true)
      if [[ -n "$loc" ]]; then awk 'NR<=20' <<<"$loc"; else echo "(none — db missing? run: nix-index)"; fi
      echo '```'
    else
      echo "(not in PATH; nix-locate unavailable)"
    fi

    hdr "man"
    echo '```'
    if man -w -- "$cmd" >/dev/null 2>&1; then
      MANWIDTH=100 man -P cat -- "$cmd" 2>/dev/null | col -bx | cap 200
    else
      echo "(no man page)"
    fi
    echo '```'

    hdr "--help"
    echo '```'
    if [[ -n "$real" ]]; then
      { timeout 5 "$real" --help </dev/null 2>&1 \
        || timeout 5 "$real" -h </dev/null 2>&1 \
        || echo "(no --help)"; } | cap 80
    else
      echo "(not installed — skipped)"
    fi
    echo '```'

    if [[ -n "$out" && -d "$out/share/doc" ]]; then
      while IFS= read -r f; do
        hdr "doc: ''${f#"$out/"}"
        echo '```'
        cap 120 <"$f"
        echo '```'
      done < <(find "$out/share/doc" -maxdepth 3 -type f -iname 'README*' 2>/dev/null | head -3)
    fi
  '';
}
