# Evaluate a flake's outputs without `builtins.getFlake`, by reading flake.lock
# and resolving inputs via fetchTarball-with-sha256 (which any FOD-capable
# evaluator has). Lets iets do the heavy module-system eval; cppnix has already
# populated the store from normal flake usage.
#
# Usage (default.nix in a flake repo):
#   import ./path/to/flake-shim.nix ./.
#
selfPath:
let
  inherit (builtins) fromJSON readFile mapAttrs fetchTarball pathExists;

  lock = fromJSON (readFile (selfPath + "/flake.lock"));
  rootName = lock.root or "root";

  fetch = locked:
    if locked.type == "github" then fetchTarball {
      url = "https://github.com/${locked.owner}/${locked.repo}/archive/${locked.rev}.tar.gz";
      sha256 = locked.narHash;
    }
    else if locked.type == "git" || locked.type == "gitlab" || locked.type == "sourcehut" then fetchTarball {
      url = locked.url or "https://${locked.host or "gitlab.com"}/${locked.owner}/${locked.repo}/-/archive/${locked.rev}.tar.gz";
      sha256 = locked.narHash;
    }
    else if locked.type == "path" then /. + locked.path
    else if locked.type == "tarball" then fetchTarball { url = locked.url; sha256 = locked.narHash; }
    else throw "flake-shim: input type '${locked.type}' not handled";

  # lock.nodes.<n>.inputs maps input-name → either a node-name (string) or a
  # follows-path (list of strings). Resolve to a node name.
  resolveRef = ref:
    if builtins.isList ref
    then builtins.foldl' (cur: k: resolveRef lock.nodes.${cur}.inputs.${k}) rootName ref
    else ref;

  selfSrc = (builtins.fetchGit selfPath).outPath;

  callNode = nodeName:
    let
      node = lock.nodes.${nodeName};
      src = if nodeName == rootName then selfSrc else fetch node.locked;
      sourceInfo = {
        outPath = src;
        narHash = node.locked.narHash or "";
        rev = node.locked.rev or "dirty";
        shortRev = builtins.substring 0 7 (node.locked.rev or "dirtydirty");
        lastModified = node.locked.lastModified or 0;
        lastModifiedDate = "19700101000000";
      };
      isFlake = (node.flake or true) && pathExists (src + "/flake.nix");
      subInputs = mapAttrs (_: ref: callNode (resolveRef ref)) (node.inputs or { });
      result =
        let
          flake = import (src + "/flake.nix");
          outputs = flake.outputs (subInputs // { self = result; });
        in
        sourceInfo // { inherit outputs; inputs = subInputs; _type = "flake"; } // outputs;
    in
    if isFlake then result else sourceInfo;

in
callNode rootName
