{ inputs, lib, ... }:
let
  # Private git+ssh:// inputs: root on the target host has no SSH key, so
  # `toString inputs.<x>` forces a fetch that fails at build time. They're
  # admin-side tools anyway — not useful as `nix run <name>#…` on targets.
  private = [ "kin" "iets" "nix-skills" ];
in
{
  # Override the registry for all the inputs that we're using. That avoids
  # annoying issues where nixpkgs gets TTL-ed.
  nix.registry = lib.mapAttrs (_name: value: {
    to = {
      type = "path";
      path = toString value;
    };
  }) (removeAttrs inputs private);
}
