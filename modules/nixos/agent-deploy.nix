{ lib, ... }:
let
  # The Claude Code agent runs as the zimbatm user on agents.ztm.io and deploys
  # by `nix copy` + switch-to-configuration as root on the target. This grants
  # that key (~/.ssh/id_ed25519 on agents) root login.
  #
  # Deliberately NOT in common.nix / zimbatm.nix: the private key lives
  # unprotected on a cloud box and is driven by an LLM, so it's scoped to the
  # cloud servers that import this module and is kept off the nv1 laptop.
  agentDeployKey = lib.removeSuffix "\n" (builtins.readFile ../../keys/agent-deploy.pub);
in
{
  users.users.root.openssh.authorizedKeys.keys = [ agentDeployKey ];
}
