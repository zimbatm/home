# bug: limine 11.4.0 BIOS-boot fails on Hetzner Cloud (relay1 bricked, web2 at risk)

**What:** nixpkgs 0726a0e ships limine 11.4.0, whose new limlz BIOS
decompressor has known spurious "limine integrity error" failures on
legacy x86 BIOS (fixed upstream in 11.4.1, released next day). Both
servers use kin `profile = "hetzner-cloud"` → limine + BIOS-boot.

**Why:** `kin deploy --action boot relay1` (gen-17, 8mfqxwb0) + reboot
left relay1 dark for ~25min — no ping, no journal entries (kernel never
loaded). Recovered via Hetzner rescue: chroot + gen-16's
`switch-to-configuration boot` reinstalled limine 11.3.1 stage1/stage2.
web2 had the same gen staged; rolled back to gen-25 before reboot.

Evidence chain:
- `default_entry` sed to gen-16 + 11.4.0 binaries → still no boot
- gen-16's installer (limine 11.3.1) → boots in ~10s
- `nix-store -qR <gen-17>` → `mhyyh62y…-limine-11.4.0` (bios.sys 258500B)
- 11.3.1 bios.sys = 261092B (size delta = new compressor)
- Upstream ChangeLog v11.4.1: "Fix limlz… spurious failures ('limine
  integrity error') on the legacy x86 BIOS port"
- nixpkgs master has 12.0.2; nixos-unstable still 11.4.0

**How-much:** ~0.2r. Override `boot.loader.limine.package` to ≥11.4.1
where the hetzner-cloud profile applies (relay1+web2). limine isn't
referenced in modules/ or machines/ — it comes from kin's profile, so
override in a shared server module or per-host. Candidate:

```nix
boot.loader.limine.package = pkgs.limine.overrideAttrs (_: rec {
  version = "11.4.1";
  src = pkgs.fetchurl {
    url = "https://github.com/Limine-Bootloader/Limine/releases/download/v${version}/limine-${version}.tar.gz";
    hash = lib.fakeHash;  # fill via nix build
  };
});
```

Then re-attempt `kin deploy --action boot <host>` + reboot (one host
first, verify, then the other). dbus-broker switchInhibitor still
applies, so it's boot+reboot regardless.

**Blockers:** none for the override. Actual deploy+reboot is
human-gated (ops-deploy-{relay1,web2}). Drop the override once
nixos-unstable picks up ≥11.4.1.

Side finding (separate item if confirmed): NixOS limine module sets
`default_entry: 2` = highest-numbered generation regardless of where
`/nix/var/nix/profiles/system` points — `--rollback boot` doesn't
change the boot default unless the higher gen-link is also removed.
Observed in rescue; worth a nixpkgs issue if reproducible outside.
