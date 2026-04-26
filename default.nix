# Non-flake entrypoint for evaluators without flake support (iets).
# Bootstrap: fetch kin from flake.lock, import its flake-shim, which then
# resolves all other inputs from the same lock via fetchTarball.
#
# Consumers (do NOT drop until both gone — kin-infra@2f4c9454 dropped this
# thinking .envrc was the only one; `kin gen` broke):
#   - .envrc iets arm: MIGRATED to `iets-compat iets-flake build` (this commit)
#   - ../kin/cli/kin/evaluator.py Iets.eval_attr: still `import default.nix`
#     → cross-filed ../kin/backlog/feat-evaluator-iets-flake-entrypoint.md;
#     drop this file once that lands and a kin bump past it is pinned here.
let
  lock = builtins.fromJSON (builtins.readFile ./flake.lock);
  k = lock.nodes.kin.locked;
  url =
    if k.type == "github" then
      "https://github.com/${k.owner}/${k.repo}/archive/${k.rev}.tar.gz"
    else
      let
        m = builtins.match "ssh://git@github.com/([^/]+)/(.+)" k.url;
      in
      "https://github.com/${builtins.elemAt m 0}/${builtins.elemAt m 1}/archive/${k.rev}.tar.gz";
  kinSrc = builtins.fetchTarball {
    inherit url;
    sha256 = k.narHash;
  };
in
import (kinSrc + "/lib/flake-shim.nix") ./.
