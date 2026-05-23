---
title: the nix configuration
created: '2022-08-18'
updated: '2022-08-18'
date: '2022-08-18'
tags:
- Nix
- Tutorial
---

There are some surprising corner cases with how Nix handles its configuration. My goal with this article is to clarify your mental model. I will take a few shortcuts to keep this focused on the high-level mechanisms.

## Baseline

The first thing to establish is Nix has a client (nix CLI) / server (nix-daemon) architecture.

They read the same configuration format but look at different places and don’t look at different keys in the file (with some overlapping).

Configuration reference:

[https://nixos.org/manual/nix/stable/command-ref/conf-file.html](https://nixos.org/manual/nix/stable/command-ref/conf-file.html)

## Server

The nix-daemon reads from `/etc/nix/nix.conf`.

The configuration is loaded while the process is starting. If you change the config, don’t forget to restart the nix-daemon (eg: `pkill nix-daemon`). On NixOS this is handled automatically for you.

The server is mainly interested in configuration keys that change the building environment. Things like where to substitute existing build results from, how the build [`sandbox`](https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-sandbox) is configured, the [`max-jobs`](https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-max-jobs) concurrency, …, and who are the [`trusted-users`](https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-trusted-users) (more on this later).

## Client

The client reads its config from `$NIX_USER_CONF_FILES`, `~/config/nix/nix.conf` and also `/etc/nix/nix.conf`, merging all the keys from right to left.

The client is mainly concerned about evaluation and CLI settings, like the [`nix-path`](https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-nix-path), [`restrict-eval`](https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-restrict-eval), if flakes are enabled, …

## Overriding server configuration from the client (trusted-users)

We’re getting to the meat of the confusion.

When the nix client initiates a build (aka “realizes the derivation”), the nix client reads `/etc/nix/nix.conf`, and diffs it with its current configuration. If it sees changes in `substituters` and other build-specific configurations, it will forward them to the server along the build.

> Changing build configuration can affect the system’s integrity. This allows replacing `/nix/store` entries with corrupted payloads (like viruses). And probably escalate permissions to root.

So by default, the server rejects configuration changes. Unless the sending user is part of the `trusted-user` list. If you ever saw an error message saying you are not a trusted user, that’s why.

On the other hand, this is very handy for setting per-project caches. Typically each project has its binary cache, and changing the server configuration on every project switch takes a while.

TODO: I’m not sure, but I don’t think what is described here works with remote builders. Even if it worked, it doesn’t know what the remote builder config looks like, it’s only comparing it to `/etc/nix/nix.conf`.

## Flakes

Talking about flakes, if the `flake.nix` has a `nixConfig` section, the client will also load config from there.

Even if the user is not a trusted-user, this is a standardized place to document your project’s requirements. Eg:

```nix
{
  description = "My flake";

  # Points to our cache containing all the build results published by the CI.
  nixConfig.extra-substituters = [ "https://nix-community.cachix.org/" ];
  nixConfig.extra-trusted-public-keys = [ "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs=" ];

  # ...
  inputs = {};
  outputs = { self, ... }: {};
}
```

Before applying the changes, the Nix CLI will ask you if you trust the configuration changes. This makes it safer to have your user be part of the system’s `trusted-users` list (assuming you trust that user).

## Conclusion

As you might notice, I didn’t specify which configuration key applies to the server or the client. This belongs to the reference documentation. Hopefully, somebody will be motivated to fix it. 😇

As usual, ping me if anything here needs some clarification.
