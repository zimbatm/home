---
title: 1000 instances of nixpkgs
created: '2022-01-13'
updated: '2023-10-27'
date: '2022-01-26'
tags:
- Nix
---

> 💡 If you are coming here from the Determinate Systems article, you might come with the impression that this article is anti-flake. This isn’t the case. The purpose of this article is to talk about a specific issue that I see arriving down the road.

This is a bit of a PSA for the NixOS community (and me), to try and expose something that I see:

> 💡 dependencies should not create their own instance of nixpkgs

Especially with the advent of Flakes, soon enough, we will end up with 1000 dependencies, each with its own instance of nixpkgs. Given that nixpkgs takes around 100MiB of RAM and a second to evaluate, that can quickly add up.

## How we got there

Overlays everywhere. Here is an example of one of my own projects:

```nix
pkgs = import inputs.nixpkgs {
  inherit system;
  config = { };
  overlays = [
    (final: prev: {
      fenix = import inputs.fenix {
        pkgs = prev;
      };
    })
  ];
};
```

nixpkgs overlays are super useful. They are a mechanism that allows taking nixpkgs, and extending it with your own packages and overrides. In most cases, it’s more manageable than forking nixpkgs and managing your own long-running branch. NixOS also doesn’t provide a standard way to have other package sets so it makes sense to have them all in one. Those two reasons are what made them popular.

There is just one problem; overlays are only usable when creating a new instance of nixpkgs. It’s time to stop using overlays (in most cases, see below).

## Solution; composition over inheritance

This title doesn’t make 100% sense but you get it, compose instead of extending nixpkgs. Here are a few scenarios that you might encounter with proposed solutions:

### Nix classic

Typically, in a Nix classic project, dependencies are pinned using [niv](https://github.com/nmattia/niv), and then you compose the different sources with something like this:

```nix
{ system ? builtins.currentSystem }:
let
  sources = ./nix/sources.nix;

  pkgs = import sources.nixpkgs {
    inherit system;
    config = { };
    overlays = [(final: prev: {
      other-dep = import sources.other-dep { pkgs = prev; };
    })];
  };
in
# your code here accessing `pkgs.other-dep`
```

Instead of creating this one instance with an overlays, split it up like this:

```nix
{ system ? builtins.currentSystem
, sources ? import ./nix/sources.nix
, nixpkgs ? import sources.nixpkgs { inherit system; config = { }; overlays = [ ]; }
, other-dep = import sources.other-repo { pkgs = nixpkgs; };
}:
# your code here accessing `nixpkgs` and `other-dep`
```

Exposing the constructors as a function argument allows a consumer of your project to inject their own instance of nixpkgs in there, and avoid creating a new instance. And also provide their own version of other-dep if they want to.

> 💡 `pkgs` has been renamed to `nixpkgs` to make it clear that it’s just nixpkgs and not a random set of packages.

### Nix Flakes

Here is a synthetic example of what a Flake typically looks like:

```nix
{
  description = "My flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.other-dep.url = "github:other/dep";

  outputs = { self, nixpkgs, other-dep }: {
      packages = nixpkgs.lib.genAttrs [ "x86_64-linux" ] (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [(final: prev: {
              other-dep = import sources.other-dep { pkgs = prev; };
            })];
          };
        in
        # your code here accessing `pkgs` and `pkgs.other-dep`
     );
  };
}
```

Instead of instantiating a new nixpkgs, access `nixpkgs.legacyPackages.${system}` and then make sure that all dependencies use the same instance of nixpkgs.

```nix
{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  inputs.other-dep.url = "github:other/dep";
  # Use the same version of nixpkgs as us
  inputs.other-dep.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, other-dep }@inputs: {
      packages = nixpkgs.lib.genAttrs [ "x86_64-linux" ] (system:
        let
          p = {
            nixpkgs = inputs.nixpkgs.legacyPackages.${system};
            # other-dep would also access `inputs.nixpkgs.legacyPackages.${system}`
            # thus only using a single instance of it.
            other-dep = inputs.other-dep.packages.${system};
          };
        in
        # your code here accessing `p.nixpkgs` and `p.other-dep`
     );
  };
}
```

That way, there will only be a single instance of nixpkgs being evaluated, and consumers of your project can again follow the same practice.

### NixOS

NixOS is a tough one because there are interactions between the module system and the packages. When using `nixos-rebuild`, NixOS will create its own instance of nixpkgs, based on the NIX_PATH and channels by default, and configured by [the](https://search.nixos.org/options?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=nixpkgs.) [`nixpkgs.*`](https://search.nixos.org/options?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=nixpkgs.) [options](https://search.nixos.org/options?channel=unstable&from=0&size=50&sort=relevance&type=packages&query=nixpkgs.). Or when using flakes, it calls `pkgs.nixos` that injects its own instance of nixpkgs to the `nixpkgs.pkgs` option. There isn’t really room to provide more package sets side-by-side.

Luckily NixOS is a bit out of scope for this article because typically NixOS configs are at the root of the dependency tree 😅.

Ideally, we would introduce a new top-level `packages` attribute that can hold package sets side by side and would be used like this:

```nix
{ config, ... }:
{
  systemPackages = [ config.packages.nixpkgs.hello ];
}
```

## Some more arguments against overlays

Did you ever hit hard to debug infinite recursion issues? Without overlays, those are gone.

Given that the instance of pkgs is a global namespace, it can become difficult to reason about it once a few overlays have been added. Are they all using their own prefix inside of that global namespace? Is there any chance they might clash over each other? Are they overriding existing packages? All of this is gone without overlays.

Overlays are opaque before being applied. So tools like `nix flake show` won’t be able to inspect their content.

## When to use overlays

To being said, even with all these arguments against overlays, there are places where they are still useful:

Contrary to what I said, if there are no Nix consumers of your repository, then don’t mind me, go crazy. This article is really aimed at 3rd-party dependencies and hopes to change the status quo.

Another example would be if your project really needs to patch nixpkgs. To get a whole set of nixpkgs out, with some internal dependency replaced with your own version. Imagine needing nixpkgs, but with a different version of OpenSSL, or different build flags. The point is that in these cases, you wouldn’t add new attributes to nixpkgs and only modify existing ones.

# Conclusion

In this article we have seen two things; when to use overlays, and how to avoid creating too many instances of nixpkgs. Of course, the reality is always more nuanced than the points and I’m sure you will find corner cases where you still need to reach for those tools. But I hope you got the overall points and that it made sense.

Thanks for reading!

For comments and discussion: [https://discourse.nixos.org/t/1000-instances-of-nixpkgs/17347/1](https://discourse.nixos.org/t/1000-instances-of-nixpkgs/17347/1)
