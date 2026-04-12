# harness-fmt-and-checks

## What

Convert `formatter` from bare nixfmt to treefmt-nix wrapping nixfmt; add
`checks.${system}` so `nix flake check` evals all hosts.

## Current state

`formatter` = nixfmt directly (the only sibling where `nix fmt` works today).
No `checks`.

## Change

```nix
inputs.treefmt-nix = { url = "github:numtide/treefmt-nix"; inputs.nixpkgs.follows = "nixpkgs"; };

let treefmtEval = treefmt-nix.lib.evalModule pkgs {
  projectRootFile = "flake.nix";
  programs.nixfmt.enable = true;
};
in {
  formatter.${system} = treefmtEval.config.build.wrapper;
  checks.${system} = {
    fmt = treefmtEval.config.build.check self;
  } // lib.mapAttrs (n: c: c.config.system.build.toplevel) self.nixosConfigurations;
}
```

Host-eval checks may be slow; if `nix flake check` becomes too heavy, gate
host builds behind a separate `checks-full` and keep `checks` = `{ fmt; eval-only; }`
where eval-only = `pkgs.writeText "ok" (builtins.toJSON (builtins.attrNames self.nixosConfigurations))`.

## Follow-up (after this lands)

grind.config.js fastCheck → `nix flake check`. Current fastCheck is
`nix eval .#nixosConfigurations --apply builtins.attrNames`.

## Falsifies

`nix fmt && git diff --exit-code` clean; `nix flake check` passes and evals
all 3 hosts.
