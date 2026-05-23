---
title: 'The NixOS “settings” option: when and how to use it'
created: '2023-01-20'
updated: '2023-01-23'
date: '2023-01-20'
tags:
- Nix
---

Two years ago, [@infinisil](https://github.com/infinisil) [introduced RFC 0042](https://github.com/NixOS/rfcs/pull/42), a new `settings` option to NixOS modules. Previously, to define extra settings on top of the default ones, you would use the `extraConfig` parameter. But it was inconvenient to use it, and sometimes the option exposed faulty behavior. This is all gone with `settings`, which can specify configuration files as a structural Nix value.

NixOS modules that ship with nixpkgs has been slowly adopting it and now we have some experience of how it plays out in practice.

Here I will discuss the pros and cons of `settings` and its usage: when it's appropriate to use it and when to avoid it. I'll also give you some recommendations.

## What is the `settings` option?

This new approach makes NixOS services configuration more extensible while reducing the number of module options authors have to describe. For instance, instead of writing:

```nix
services.foo.extraConfig = ''
  # Can't be set in multiple files because string concatenation doesn't merge such lists
  listen-ports = 456, 457, 458

  # Can't override this setting because the module hardcodes it
  # bootstrap-ips = 172.22.68.74

  enable-ipv6 = 0
  ${optionalString isServer "check-interval = 3600"}
'';
```

You can now write:

```nix
services.foo.settings = {
  listen-ports = [ 456 457 458 ];
  bootstrap-ips = [ "172.22.68.74" ];
  enable-ipv6 = false;
  check-interval = mkIf isServer 3600;
};
```

So, services now use pure Nix types for different settings instead of configuration file snippets.

## Upsides

The most significant benefit of `settings` is that configuration files now have the same extension properties as the rest of NixOS modules. So it's easier to set and override configuration options for any modules. So, overall, it helps with module composability.

Another benefit is that the module author doesn't have to predict where the extension points should be added; all the configuration is extensible by default.

Another bright side is that the configuration is more likely to be valid, as its evaluation is tied to the Nix evaluation. This moves most typos from runtime issues to nix evaluation time issues (but not semantic issues).

## Downsides

The users now have to convert configuration snippets from sources, such as documentation and Stackoverflow pieces of advice, to Nix code, and do it manually! This introduces manual friction and makes it harder to compare to previous or future versions of the configuration to see what changed between them.

This can be especially painful if the Nix data types don't map cleanly to the configuration format. [@tazjin](https://github.com/tazjin) showed me a [great example](https://github.com/NixOS/nixpkgs/blob/nixos-22.11/nixos/modules/services/databases/openldap.nix#L129) of such an issue the other day. A nightmare to work with!

We also had users’ reports that the capitalisation change needs to be clarified. In the nix world, we use `camelCase` but then setting keys, map 1:1 to the configuration option and might use another rule. Eg: `services.biboumi.credentialsFile` vs `services.biboumi.settings.xmpp_server_ip`.

## Recommendations to module authors

- **Avoid \*\*** `settings`\***\* if the types don't map well**. Don't use the `settings` if there is no precise 1:1 mapping between Nix data types and the target config file.
  **OK:** JSON, TOML, YAML
  **Not OK:** most of the older stuff. Nginx, OpenLDAP, Apache2, ...

- **Provide a \*\*** `configFile`\***\* escape hatch to the user.** Every module that exposes a `settings` option should also provide a `configFile` option that contains the generated config file. This gives the user an escape hatch. The option documentation should be explicit that providing an alternative `configFile` will ignore all the settings options.

```nix
config.settings.myservice.configFile = pkgs.writeText "myservice-config.toml" (''
  # Hey, I can now add comments to the config file
'' + ''
  and_compose_snippets = true
'');
```

- **Provide Nix library to load configuration snippets.** In order to retain the ability to copy-paste snippets around, it would be nice to provide a pure Nix parsing library that can convert the configuration snippet to Nix data. This is a stretch goal and has some evaluation performance implications. Eg:

```nix
services.myservice.settings = lib.fromTOML ''
  user = "hello"
'';
```

## Conclusion

Here, I explored what the `settings` - the new option in nix modules are. I looked at the upsides and downsides and gave some advice on its usage.

So now you are informed to employ it as intended!

### Extra notes

[https://github.com/NixOS/nixpkgs/issues/144575](https://github.com/NixOS/nixpkgs/issues/144575)
