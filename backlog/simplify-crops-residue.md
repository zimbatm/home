# simplify-crops-residue

## what

Delete the dead crops-demo userland circle and the orphaned `pciAddr` option —
both are residue from e98e1c5 (crops-demo input drop) that the vendoring pass
left behind.

Two pieces, one root cause, one PR:

1. **crops.nix stub + nv1 setter** — `modules/home/desktop/crops.nix` (14L)
   declares `home.crops.enable` (mkEnableOption, default false) solely so that
   `machines/nv1/configuration.nix:92-94` can set it to `false`. The setter
   exists only because the option exists; the option exists only so the setter
   doesn't error. The throw at crops.nix:9-12 is unreachable. Delete crops.nix,
   its import at `modules/home/desktop/default.nix:31`, and nv1 lines 92-94.

2. **vfio-host `crops.gpu.pciAddr`** — `modules/nixos/vfio-host.nix:38-45`
   declares `pciAddr` "for interface compatibility" with the crops-demo VM
   definition that read it. That VM definition left with the crops-demo input.
   Nothing in tree sets or reads `pciAddr` (grep: 2 hits, both the declaration
   itself). Delete the option block + the `pciAddr` mention in the header
   comment (lines 5-7). 3092054 restored the "original" with this option for
   interface parity, but parity with a removed input is dead weight.

## why

-28L net; removes a whole file. home-module reachability goes 2+6 → 2+5.
The stub was intentional staging at e98e1c5 ("Option kept so existing
`home.crops.enable = false` doesn't error") to keep the drop atomic — but the
follow-through (delete both sides together) never landed. vfio-host is now
fully self-contained vendored code with no upstream to stay compatible with.

## how-much

~5 min. 3 files edited, 1 file deleted. No flake.lock change.

## gate

`nix eval .#nixosConfigurations.nv1.config.system.build.toplevel.drvPath` —
nv1 is the only host that imports both vfio-host and homeModules.desktop.
Expect drvPath unchanged (crops.enable=false was a no-op; pciAddr default
null was a no-op).

## blockers

None. Not human-gated — pure dead-code delete, no deploy needed to verify.
