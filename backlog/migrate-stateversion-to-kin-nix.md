# migrate-stateversion-to-kin-nix

## what

Move 3× `system.stateVersion` from `machines/*/configuration.nix` to
`machines.<n>.stateVersion` in `kin.nix`. The kin field exists
(spec/model.nix → lib/machine.nix `mkIf (m.stateVersion != null)`) and
`kin install` already prints the add-line, but 0/3 hosts use it — every
one routes around via the autoInclude side-channel.

| host | stateVersion | configuration.nix after |
|---|---|---|
| nv1 | `"23.05"` | keep (hardware/vfio/gnome/hm — line 71 only) |
| web2 | `"26.05"` | keep (imports/firewall/sudo) |
| relay1 | `"26.05"` | keep (`security.sudo.wheelNeedsPassword` only) |

Add to `kin.nix` machines block (line 21-25):
```nix
nv1    = { …; stateVersion = "23.05"; };
web2   = { …; stateVersion = "26.05"; };
relay1 = { …; stateVersion = "26.05"; };
```

nv1's `home-manager.users.jonas.config.home.stateVersion = "22.11"`
(line 65) stays where it is — different option, hm-scoped.

## why

`../kin-infra` a9fedd2→bb62a4b cycle filed
`../kin/backlog/feat-machine-stateversion.md` ("coincidentally equal,
not semantically shared"); kin landed the per-machine slot; neither
dogfood came back to use it. stateVersion is needed by 3/3 machines and
set via the parallel path 3/3 times — the schema field is the
implemented fix for a problem this repo still has.

## how-much

~6 lines net (+3 kin.nix attrs, -3 configuration.nix lines). Single
commit.

## blockers

None — kin pin ships the field; mkIf is plain so no priority conflict
(the autoInclude line is *removed*, not layered over).

## falsifies

```sh
for m in nv1 web2 relay1; do
  nix eval --raw .#nixosConfigurations.$m.config.system.build.toplevel.drvPath
done
```
must be byte-identical before/after. If any drvPath changes,
lib/machine.nix mkIf has a priority bug → file `../kin/backlog/`.
