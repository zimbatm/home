# activitywatch.nix: 2× identical systemd.user.services bodies

## What

`modules/home/desktop/activitywatch.nix` defines two systemd user services
with **byte-identical** `Unit` + `Install` bodies (only the attr name
differs):

```nix
systemd.user.services.activitywatch-watcher-aw-watcher-afk = {
  Unit = { After = [ "graphical-session-pre.target" "aw-server.service" ]; PartOf = [ "graphical-session.target" ]; };
  Install.WantedBy = [ "graphical-session.target" ];
};
systemd.user.services.activitywatch-watcher-aw-watcher-window-wayland = {
  # same body
};
```

22 LoC total for the two blocks.

## Why

Collapse to one definition shared across both names — net ~-14 LoC, and
adding a third watcher later is one list entry instead of an 11-line
paste:

```nix
systemd.user.services = lib.genAttrs
  [ "activitywatch-watcher-aw-watcher-afk" "activitywatch-watcher-aw-watcher-window-wayland" ]
  (_: {
    Unit = {
      After = [ "graphical-session-pre.target" "aw-server.service" ];
      PartOf = [ "graphical-session.target" ];
    };
    Install.WantedBy = [ "graphical-session.target" ];
  });
```

(Needs `lib` in the module arg-set; currently `{ pkgs, ... }:`.)

**ADR-0006 counter:** "locality over abstraction" — the explicit form is
greppable per-service. `genAttrs` is a tiny indirection. Decide: -14 LoC
vs one `genAttrs` lookup. Prior art in this repo: none either way for
systemd services. If wontfix, file it so the next sweep skips.

## How much

47 → ~33 LoC in activitywatch.nix. No eval/build/behaviour change
(module system merges to identical result).

## Gate

```sh
nix eval .#nixosConfigurations.nv1.config.home-manager.users.zimbatm.systemd.user.services --apply builtins.attrNames
nix build --dry-run .#nixosConfigurations.nv1.config.system.build.toplevel
```

Verify both `activitywatch-watcher-*` names still present in the eval.

## Blockers

None. nv1-only (sole desktop home-manager consumer). No deploy needed
to land — pure refactor, picks up on next human deploy.
