# adopt: crops-userland — import crops-demo packages + vfio-host onto nv1

## What

Consume `crops-demo` flake outputs on nv1 (input added by
`bump-add-crops-demo-input.md` — see Blockers):

1. **Replace hand-rolled vfio** in `machines/nv1/configuration.nix:42-54`
   with the exported module:
   ```nix
   imports += [ inputs.crops-demo.nixosModules.vfio-host ];
   crops.gpu = { vendor = "10de"; device = "28a0"; audio = "22be"; };
   ```
   Drop the manual `boot.initrd.kernelModules`, `extraModprobeConfig`,
   `kernelParams` vfio block — the module owns them. Verify with
   `nix eval .#nixosConfigurations.nv1.config.boot.kernelParams` →
   identical output before/after.

2. **Add crops CLIs** to `modules/home/desktop` (new
   `modules/home/desktop/crops.nix`, imported from `default.nix`):
   ```nix
   { inputs, pkgs, ... }:
   let cp = inputs.crops-demo.packages.${pkgs.system}; in
   { home.packages = [
       cp.crops-voice cp.crops-tts cp.crops-status cp.crops-research
       cp.crops-gpu-detect cp.crops-selftest cp.run-crops
     ]; }
   ```
   No services, no daemons — packages only. `crops-voice listen` and
   `run-crops --cpu` become available in the shell; wiring them to
   keybinds/systemd-user is follow-up after they're proven useful.

## Why (seed → our angle)

**Seed:** crops-demo is the assise showcase; nv1 is its reference
hardware (the `gpu-default.nix` IDs are *this laptop's* 4060). home is
already one of the two attestation builders
(`../crops-demo/nix/attestation.nix:69`). Dogfooding the userland on the
real host closes the loop the VM can't.

**Our angle:** import packages, don't copy nix expressions.
`inputs.crops-demo.packages.*` keeps a single source of truth; bumper
rotates the pin like any other input. We *don't* adopt crops-demo's
`llama-swap.nix` service module or messaging-daemon yet — `run-crops`
gives the inference API on demand without a resident service competing
with the existing `ask-local`/infer-queue path. Compare crops-voice's
wake-word loop side-by-side with the home-grown
`ptt-dictate`→`adopt-voice-intent` GBNF path — same mic, same Arc iGPU,
two implementations.

## Falsifies

- **vfio-host equivalence**: does the module produce the same
  `boot.kernelParams` + `modprobeConfig` as the hand-roll? Diff
  `nix eval` of both before swapping. Any divergence → file
  `../crops-demo/backlog/bug-vfio-host-<gap>.md` (the module is wrong,
  not nv1).
- **crops-voice vs ptt-dictate**: after a week with both bound, which
  wins on wake→action latency and false-wake rate? If crops-voice wins,
  `adopt-voice-intent` becomes "upstream the GBNF idea to crops-voice"
  instead of building parallel infra.
- **closure cost**: `nix path-info -S` on the 7 packages — if >2GiB
  (CUDA llama pulls), gate behind a `home.crops.enable` option instead
  of unconditional.

## How much

~0.5r. vfio swap is mechanical once equivalence is checked. The
home/desktop/crops.nix module is ~10 lines. Most time is the
before/after eval diff and closure-size check.

## Blockers

- **`inputs.crops-demo` does not exist yet.** adopt-niri-session landed
  nixpkgs-only @ 0ce69c5 without adding it (r14 meta re-scope; see
  `tried/adopt-niri-session.md`). Blocked on
  `bump-add-crops-demo-input.md` — bumper adds the input first
  (implementer touching flake.lock is denylisted).
- crops-demo's nixpkgs pin may diverge from ours after `follows` —
  `crops-llama` w/ CUDA may need `allowUnfree` already set (it is, via
  desktop.nix) but watch for `cudaSupport` overlay mismatch.
