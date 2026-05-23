---
title: Announcing nixpkgs-unfree
aliases:
- /notes/announcing-nixpkgs-unfree
created: '2022-02-04'
updated: '2022-02-04'
date: '2022-02-04'
tags:
- Project
---

Recently I was saying that we should avoid creating too many instances of nixpkgs. Either accept an argument or use the flake follows feature:

There is just one problem with this claim; what if you need to access unfree packages? For example, try running:

```javascript
$ nix run nixpkgs#slack

error: Package ‘slack-4.22.0’ in /nix/store/fbcgjqs34vllzzppa1y213fbxx01sxn7-source/pkgs/applications/networking/instant-messengers/slack/default.nix:83 has an unfree license (‘unfree’), refusing to evaluate.

       a) To temporarily allow unfree packages, you can use an environment variable
          for a single invocation of the nix tools.

            $ export NIXPKGS_ALLOW_UNFREE=1

       b) For `nixos-rebuild` you can set
         { nixpkgs.config.allowUnfree = true; }
       in configuration.nix to override this.

       Alternatively you can configure a predicate to allow specific packages:
         { nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
             "slack"
           ];
         }

       c) For `nix-env`, `nix-build`, `nix-shell` or any other Nix command you can add
         { allowUnfree = true; }
       to ~/.config/nixpkgs/config.nix.
(use '--show-trace' to show detailed location information)
```

Oops!

This whole error message is misleading. All the solutions proposed don’t work when using Flakes because Flakes evaluation is pure and doesn’t take your environment variables or config into account.

In order to fix that problem, allow me to introduce a new project:

[https://github.com/numtide/nixpkgs-unfree](https://github.com/numtide/nixpkgs-unfree)
It’s a small wrapper to nixpkgs with `allowUnfree = true;` enabled. I know I said not to create new instances of nixpkgs, but that’s the last one I promise 🙂

So now with that, you can run:

```plain text
$ nix run --no-write-lock-file github:numtide/nixpkgs-unfree#slack
```

It’s also usable as a flake, so you can point nixpkgs to it:

```nix
{
  inputs.nixpkgs.url = "github:numtide/nixpkgs-unfree";
}
```

In the future, I also want to also keep the channels synchronized with nixpkgs so you can run `nix run github:numtide/nixpkgs-unfree/<channel>`. And potentially provide a binary cache for it.

That’s it for now, have a great weekend!

### Discussion

If you want to comment on the article, head over to the NixOS Discourse:

[https://discourse.nixos.org/t/announcing-nixpkgs-unfree/17505](https://discourse.nixos.org/t/announcing-nixpkgs-unfree/17505)

### Addendum: how many instances of allowUnfree are there on GitHub?

Thanks to @tazjin for pointing me to a more usable code search: [https://sourcegraph.com/search?q=context:global+file:flake.nix+allowUnfree&patternType=literal](https://sourcegraph.com/search?q=context%3Aglobal%20file%3Aflake.nix%20allowUnfree&patternType=literal)

At the time of writing, there are 218 results.
