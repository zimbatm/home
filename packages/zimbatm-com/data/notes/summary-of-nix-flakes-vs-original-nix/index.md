---
title: Summary of Nix Flakes vs original Nix
created: '2021-12-27'
updated: '2022-01-05'
date: '2021-12-27'
tags:
- Nix
---

## Quick recap

Flakes was born when Shea Levy, who worked at Target at the time, decided to hire Eelco (who works at Tweag) to solve a set of issues that Target was having.

Flakes is a set of extensions for the Nix language that is currently (Dec 2021) behind an experimental flag.

While adding a set of useful features, Flakes also gathered some controversy in the NixOS community. This article is summarizing to the best of my ability the various viewpoints of flakes.

## Flakes features

Flakes are a lot of things at the same time.

### 1. A single project entry-point

Nix is very flexible and each project tends to have a slightly different shape. Flakes introduces a top-level `flake.nix` file that serves as the main entry-point to a project. It declares inputs and outputs for the project (more on that later).

### 2. Dependency management

Flakes introduces a way to declare third-party dependencies. Instead of using a tool like `niv`, or manually updating versions and sha256, the `flake.nix` file declares all these inputs. An additional `flake.lock` file is introduced to pin those dependencies.

### 3. Pure evaluation

Flakes disables features such as `builtings.getenv`, `builtins.currentSystem`, `builtins.getCurrentTime`. Given that Nix is supposed to help make builds more reproducible, it’s nice that the evaluation is now pure by default.

### 4. Evaluation caching

With flakes being pure and controlling the inputs, it’s able to cache the evaluation outputs. The cache is currently keyed based on the Git SHA1. This allows speeding up some operations drastically.

### 5. New CLI

The Nix CLI has historically been confusing. As part of the Flakes effort, the CLI has been re-vamped to live behind a single `nix` binary, similar to how all `git` commands are living behind that name.

Note that the `nix` command was already in progress before flakes.

## Arguments against

Here are all the arguments that I have seen that are against Flakes. It’s not because I listed all of them that they are all necessarily valid. Each argument should be weighed independently.

In order of my mind remembering:

### a. Keep nixpkgs a monorepo

Some people consider that the biggest value in nix is not the language, but the `nixpkgs` repo that contains all the package definitions. And that this value is intrinsically tied to having a monorepo because it allows to easily do large refactors. Their fear is that if Flakes becomes stable, that the repository will be split into many different pieces.

Without the linerization of history, it would also become more expensive to fill the binary cache with all the possible combinations of git commits between the repositories.

### b. The Flakes RFC was closed

After long conversations, [RFC0049](https://github.com/NixOS/rfcs/pull/49) has been withdrawn. Yet Flakes still got implemented, albeit behind an experimental flag. That makes some people grumpy as they perceive it as being a breach of process.

### c. recurceIntoAttrs was lost

`nix-build` will build all the values of an attrset, and follow recursively is an attrset has a `recurseForDerivations = true;` key-value pair. Flakes now only allows building one attributes at the time, and only if it’s a derivation. This removes some heuristic in Flakes, but also prevents some use-cases like turning a monorepo into a tree of attrsets mapping the folder structure.

`nix flake check` will complain if the output of the `package` is not flat.

### d. Flake.nix is not exactly a nix file

While `flake.nix` has the syntax of a Nix file, only the outputs allow function calls. The rest of the structure is more like JSON, where only pure values are accepted.

### e. The flake.nix file is not ergonomic

The `flake.nix` output, in particular, is quite confusing to people. Most projects use the `numtide/flake-utils` repo to make them more palatable.

### f. The strict dependency on Git

A common issue that new users are facing is that flakes will complain that a file doesn’t exist, when in fact it does. The issue is that flakes only consider files that are part of the git index. `git add thefile` and then things are working again. And Flakes uses the staging area file list, but not the staging area contents. That makes the git experience counterproductive.

The strict dependency on Git means that companies that are using Mercurial or other source control won’t be able to use flakes.

### g. Evaluation caching is not useful during development

Because the evaluation is keyed on the git commit, active development on a repository will mostly likely have invalidated the evaluation cache.

### h. System tuples are hard-coded with Flakes

Before flakes appeared, nixpkgs was starting to move past the `<arch>-<kernel>` tuple (eg: `x86_64-linux`) to allow better expressing system variants such as distinctions between musl or glibc-based systems. As part of flakes’ design, the use is now locked into these tuples as they are mandated by Nix itself.

Flakes also uses these tuples quite a lot, and they are easy to mistype. Especially `x86_64-linux` that uses both an underscore and a dash.

### More?

Let me know if I forgot any major points.

## Conclusion

So here we are. With the recent Nix 2.4 release, Flakes is available behind a feature flag in a stable release. It’s being increasingly adopted by more and more people. Even though it hasn’t gone through an RFC, I think we reached a critical mass of users.

It’s unfortunate that Flakes is a bundle of features that all have to be adopted, or not. It puts us in a bit of a Python 3.0 situation, where it splits the community in two, and the transition is painful. To me, there are clearly good arguments on both sides.
