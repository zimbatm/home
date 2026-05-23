---
title: Garnix is so good. It's suprising it's not the default CI for all new Nix projects.
date: '2024-12-23'
created: '2024-12-23'
updated: '2024-12-23'
---

Is something I said on Bluesky last week. Here is a longer take on this:

I know [Garnix](https://garnix.io/) quite well. We have the pleasure to count them as one of Numtide's customers. Julian and I launched the Nix Swiss-French meetup together. And I have been using them on my home repository for the past 6 months. So that's the disclaimer and context.

It's also why I know and understand Garnix quite well. Like I said in my post, it's surprising to me that not more people are using it today. To me, Garnix is the perfect Nix CI. Let me share what I see:

1. No CI-specific YAML. Whatever is in your flake.nix that runs on your machine, also runs in CI.
1. No vendor lock-in. If you don't like it anymore, it's easy to move back to GitHub Actions, or deploy your own buildbot-nix instance.
1. A globally shared binary cache.garnix.io. So every new project feeds and shares their build results. Faster compile for everyone. And no need to configure a different cache for each project. And because only the Garnix CI can push to the cache, you only need to trust the Garnix build infrastructure.
1. Supports the quad: Linux and macOS. Both with x86_64 and aarch64.
1. 30s runs with hot `/nix/store`. Unlike GitHub Actions, builders don't flush their `/nix/store` on every run. That, and good hardware is what makes it possible to get ultra fast build turnarounds.
   **TL;DR: Point Garnix to your repo with a flake.nix in it, and you have a CI.**

Then combine this with [blueprint](https://github.com/numtide/blueprint) to keep your flake super lean. Mergify + renovate to get automated flake updates. And you have a really nice setup.

The best is when I pull my dotfiles repo and everything is already prebuilt. No amount of customization I do on top of nixpkgs and NixOS is going to penalize me. And Nix is really _the_ language for people that like to fearlessly customize things.

Ok, enough rambling for a day. Does the vision make sense or are there aspects you’re considering that I haven’t touched upon?

[https://garnix.io/](https://garnix.io/)
