{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "kin-opts";
  runtimeInputs = [ pkgs.nix pkgs.jq pkgs.git ];
  text = ''
    # Fleet-local NixOS option introspection. Answers from *this flake's*
    # evaluated module system (kin + maille + local modules), not upstream docs.
    #   kin-opts --hosts                   → list nixosConfigurations
    #   kin-opts <host> <path>             → option leaf: {value,type,description,declared,defined}
    #                                        attrset: {children:[...]}
    #   kin-opts <host> --search <regex>   → option paths matching regex (full tree)
    # FLAKE override: KIN_OPTS_FLAKE (default: git toplevel, else .)
    flake="''${KIN_OPTS_FLAKE:-$(git rev-parse --show-toplevel 2>/dev/null || echo .)}"

    usage() {
      echo "usage: kin-opts --hosts" >&2
      echo "       kin-opts <host> <option.path>" >&2
      echo "       kin-opts <host> --search <regex>" >&2
      exit 2
    }

    [[ $# -ge 1 ]] || usage

    if [[ "$1" == "--hosts" ]]; then
      nix eval "$flake#nixosConfigurations" --apply builtins.attrNames --json | jq -r '.[]'
      exit
    fi

    host="$1"; shift
    [[ $# -ge 1 ]] || usage

    if [[ "$1" == "--search" ]]; then
      pat="''${2:?--search needs a regex}"
      # shellcheck disable=SC2016
      exec nix eval "$flake#nixosConfigurations.$host.options" --json --apply '
        opts:
        let
          isOpt = o: (o._type or null) == "option";
          go = p: o:
            let t = builtins.tryEval (builtins.isAttrs o); in
            if !(t.success && t.value) then [ ]
            else if isOpt o then [ p ]
            else builtins.concatMap (k: go (if p == "" then k else p + "." + k) o.''${k}) (builtins.attrNames o);
        in builtins.filter (p: builtins.match ".*('"$pat"').*" p != null) (go "" opts)
      ' | jq -r '.[]'
      exit
    fi

    path="$1"
    # shellcheck disable=SC2016
    if ! out=$(nix eval "$flake#nixosConfigurations.$host.options.$path" --json --apply '
      o:
      let
        isOpt = (o._type or null) == "option";
        try = v: let r = builtins.tryEval v; in if r.success then r.value else "<eval error>";
      in
      if isOpt then {
        kind = "option";
        value = try o.value;
        type = o.type.description or null;
        description = o.description or null;
        declared = o.declarations or [ ];
        defined = try (map (d: { inherit (d) file; value = try d.value; }) (o.definitionsWithLocations or [ ]));
      } else {
        kind = "attrset";
        children = builtins.attrNames o;
      }
    ' 2>&1); then
      echo "kin-opts: option '$path' does not exist on '$host'" >&2
      echo "  try: kin-opts $host --search '<substring>'" >&2
      echo "  or drill down from a parent path to see {children}" >&2
      exit 1
    fi
    jq --arg p "$path" '. + {path:$p}' <<<"$out"
  '';
}
