---
title: Nix 2.6 eval improvement
created: '2022-01-25'
updated: '2022-01-25'
date: '2022-01-25'
tags:
- Nix
---

With the recent [Nix 2.6 release](https://discourse.nixos.org/t/nix-2-6-0-released/17324), I was curious about how much impact all of @pennae’s work was having on the Nix evaluation.

> TL;DR: Nix evaluation is 11-17% faster in Nix 2.6 compared to Nix 2.5.1

## Methodology

I have both the nix and nixpkgs repo side by side.

nixpkgs is checked out at ac44b27bab615fd49bc94fe22124deae233b5c94 (latest master)

nix is checked out at 2.6.0

Then run `nix-build pkgs/top-level/release.nix -A metrics` and collect the output.

For nix 2.5.1 I added a space change to pkgs/top-level/metrics.nix to force the rebuild on my machine.

For nix 2.6 I injected the version from the nix repo:

```diff
diff --git a/pkgs/top-level/metrics.nix b/pkgs/top-level/metrics.nix
index d413b881eaa..cf065697923 100644
--- a/pkgs/top-level/metrics.nix
+++ b/pkgs/top-level/metrics.nix
@@ -2,11 +2,17 @@

 with pkgs;

+let
+  nix = (import ../../../nix).defaultPackage.${pkgs.system};
+in
+
```

Then I took all the results and painstakingly inserted them in Notion, for your pleasure and mine:

| Metric                              | 2.5.1        | 2.6.0        | Diff % |
| ----------------------------------- | ------------ | ------------ | ------ |
| nix-env.qaCount                     | 38784        | 38784        |        |
| nix-env.qaDrvAggressive.values      | 101913915    | 101689635    |        |
| nixos.kde.maxresident               | 572032 KiB   | 560300 KiB   |        |
| nix-env.qaDrv.allocations           | 8828388424 B | 8641514600 B |        |
| nixos.smallContainer.allocations    | 280278984 B  | 270314728 B  |        |
| nix-env.qa.allocations              | 1589209632 B | 1533671496 B |        |
| nix-env.qaDrv.time                  | 58.0178 s    | 54.589 s     |        |
| nixos.kde.time                      | 1.96151 s    | 1.74307 s    |        |
| nixos.lapp.time                     | 1.62311 s    | 1.43888 s    |        |
| nixos.kde.values                    | 5314604      | 5188433      |        |
| nix-env.qaDrv.maxresident           | 6430276 KiB  | 6558340 KiB  |        |
| nix-env.qa.values                   | 13927806     | 14326969     |        |
| nix-env.qaCountBroken               | 2666         | 2666         |        |
| nixos.lapp.allocations              | 363063272 B  | 349837776 B  |        |
| nixos.kde.allocations               | 422864776 B  | 409517776 B  |        |
| nixos.smallContainer.time           | 1.02288 s    | 0.861962 s   |        |
| nix-env.qaDrvAggressive.allocations | 8828388424 B | 8641514600 B |        |
| nix-env.qa.maxresident              | 2199724 KiB  | 2220716 KiB  |        |
| nix-env.qaAggressive.maxresident    | 2199728 KiB  | 2220736 KiB  |        |
| nix-env.qa.time                     | 8.62761 s    | 7.51825 s    |        |
| nix-env.qaDrv.values                | 101913915    | 101689635    |        |
| nix-env.qaDrvAggressive.time        | 57.418 s     | 54.3827 s    |        |
| loc                                 | 2341615      | 2341619      |        |
| nix-env.qaAggressive.values         | 13927806     | 14326969     |        |
| nix-env.qaAggressive.time           | 8.57256 s    | 7.62719 s    |        |
| nixos.lapp.values                   | 4697517      | 4572023      |        |
| nixos.smallContainer.values         | 3341438      | 3243496      |        |
| nixos.mallContainer.maxresident     | 480160 KiB   | 458036 KiB   |        |
| nix-env.qaAggressive.allocations    | 1589209632 B | 1533671496 B |        |
| nix-env.qaDrvAggressive.maxresident | 6429816 KiB  | 6558460 KiB  |        |
| nixos.lapp.maxresident              | 560988 KiB   | 550420 KiB   |        |
