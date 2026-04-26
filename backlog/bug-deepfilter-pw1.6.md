# bug: home.deepfilter dropin blocks pipewire startup on pw 1.6

## What

`modules/home/desktop/deepfilter.nix:30` writes a pipewire `filter-chain`
dropin where `plugin` is the absolute store path
`${pkgs.deepfilternet}/lib/ladspa/libdeep_filter_ladspa.so`. On pipewire
1.6.3 (current nixpkgs), filter-chain treats `plugin` as a **basename**
to look up inside pipewire's LADSPA search path
(`/nix/store/.../pipewire-ladspa-plugins/lib/ladspa/`). The aggregate
symlinkJoin doesn't include `deepfilternet`, so the lookup fails:

```
failed to load plugin '/nix/store/…/libdeep_filter_ladspa.so'
  in '/nix/store/…-pipewire-ladspa-plugins/lib/ladspa':
  No such file or directory
spa.filter-graph: can't load plugin type 'ladspa'
pw.conf: could not load mandatory module "libpipewire-module-filter-chain"
default: failed to create context
```

`libpipewire-module-filter-chain` is loaded as **mandatory**, so pipewire
exits 254 → systemd `start-limit-hit` → no audio at all on the host.
Workaround applied 2026-04-26: `home.deepfilter.enable = false;` on nv1
+ removed the live dropin symlink under `~/.config/pipewire/pipewire.conf.d/`.
The .so itself is fine (59 MB, ELF, ldd clean) — schema mismatch only.

## Why

Daily-driver audio regression. Latent since the pipewire bump that
brought 1.6 in; only surfaces when pipewire actually restarts (reboot,
not switch-to-configuration). Got caught by the nv1 reboot for the
nvidia-driver swap (commit 7bdd14f); unrelated to that change.

## How much

Two reasonable shapes — pick one:

1. **Switch to basename + extend LADSPA search path.** Set
   `plugin = "libdeep_filter_ladspa";` in the dropin and arrange for
   `pkgs.deepfilternet/lib/ladspa` to be on pipewire's plugin search
   path. NixOS exposes `services.pipewire.extraLv2Packages`-style hooks
   for some plugin types but not LADSPA directly; may need
   `environment.sessionVariables.LADSPA_PATH` or a wrapper around
   pipewire's systemd unit.
2. **Use `path` instead of `plugin` if pw 1.6 supports it.** Some 1.6
   filter-graph examples in upstream issues use `path` for absolute
   locations. Confirm against the running pipewire's source/docs before
   committing.

Option 1 is the canonical pipewire model; option 2 keeps the module
self-contained. ~30L module change either way + a deploy.

## Blockers

Needs a person to deploy + verify pipewire starts cleanly + verify
the DeepFilter virtual source actually denoises (wpctl status shows
the filter-chain node, mic test before/after).
