---
title: Nix packaging, the heretic way
created: '2022-06-23'
updated: '2022-07-05'
date: '2022-07-05'
tags:
- Nix
---

One difficulty when using Nix is that it’s possible to hit a purity wall. A dependency is not in nixpkgs (yet), and you have to package it yourself. But the project does some impure things during the build. It’s using some esoteric language that doesn’t have a `<lang>2nix` tool yet.

And sometimes it’s hard to go to your customer/boss and tell them you have to spend the next 3 weeks doing “things right”(tm).

Luckily there is a workaround available, and this is why I’m writing this article. To show a quick but impure alternative that can be used in a pinch.

> **Don’t use this for nixpkgs** - PRs will be rejected. And Hydra doesn’t build those either.

## Use `__noChroot = true` in a pinch

By default, derivations are built in a sandboxed environment, that doesn’t allow them to use the network. This is one of the core features that is used to make builds more reproducible. And also one of the main reasons why an impure build would fail.

By adding `__noChroot = true` on a derivation, it turns off the sandbox selectively for that derivation. Note that all users also need to have [`sandbox = relaxed`](https://nixos.org/manual/nix/stable/command-ref/conf-file.html#conf-sandbox) set in their `nix.conf` or `nixConfig.sandbox = "relaxed"` in their flake.nix.

So this is not a good solution for open source projects but can work in an enterprise setting, which is the only place I recommend using this.

## Example packaging flow-bin

[flow-bin](https://github.com/flow/flow-bin) is missing from nixpkgs. It’s just an example that I found that is node, and that ships with a pre-compiled binary. You could try to use node2nix, npm2nix, npmlock2nix, yarn2nix (2 versions), … Or just do this hacky thing 🙂

```nix
{ nixpkgs ? import <nixpkgs> { } }:
let
  version = "0.105.1";
in
nixpkgs.runCommand "flow-bin-${version}"
{
  # Disable the Nix build sandbox for this specific build.
  # This means the build can freely talk to the Internet.
  __noChroot = true;

  # Add all the build time dependencies
  nativeBuildInputs = [
    # Automatically patchelf all installed binaries
    nixpkgs.autoPatchelfHook
  ];

  # Add all the runtime dependencies
  buildInputs = [
    nixpkgs.nodejs
  ];
}
	# This part is a bit like a Dockerfile, without the apt-get installs.
  ''
    # Nix sets the HOME to something that doesn't exist by default.
	  # npm needs a user HOME.
    export HOME=$(mktemp -d)

    # Install the package directly from the Internet
    npm install flow-bin@${version}

    # Fix all the shebang scripts in the node_modules folder.
    patchShebangs .

    # Copy the node_modules and friends
    mkdir -p $out/share
    cp -r . $out/share/$name

    # Add a symlink to the binary
    mkdir $out/bin
    ln -s $out/share/$name/node_modules/.bin/flow $out/bin/flow
  ''
```

This kind of approach is quite generally applicable and should work for other languages as well. Of course it’s less reproducible, and if anything changes in the build script, there are no incremental build layers like in Docker.

You could split the build into different phases though, and that’s what we’ll be seeing next.

## Example packaging a NextJS project

In this case, the code changes quite often and comes from the monorepo directly. We are not packaging a third-party library, but something that our developers are evolving daily.

We were using [npmlock2nix](https://github.com/nix-community/npmlock2nix) to translate the npm package-lock.json to Nix at evaluation time. It’s a great project but, unfortunately, it [doesn’t support the package-lock.json v2 format](https://github.com/nix-community/npmlock2nix/issues/140). This is not a criticism of the project itself, it’s just a lot of work to keep up with the nodejs ecosystem (and the format itself got even more complicated).

This meant that we were stuck with nodejs 14.x, which is 2 years old and [is not actively supported anymore](https://endoflife.date/nodejs). And most frontend developers on the team also didn’t care about Nix and just installed nodejs directly in their macOS, meaning they had the latest version that generates v2 formats.

So `__noChroot = true` comes to the rescue. Here we split the build and install the `node_modules` impurely, but keep the core project sandboxed. This allows to minimize the surface and rebuild that happens.

```nix
# Fill these arguments how you like
{ nixpkgs ? import <nixpkgs> { }
, nix-filter # an instance of https://github.com/numtide/nix-filter
}:
let self =
{
  # Pick the version of nodejs to use
  nodejs = nixpkgs.nodejs_18-x;

  # Build the node_modules separately, from package.json and package-lock.json.
  #
  # Use __noChroot = true trick to avoid having to re-compute the vendorSha256 every time.
  node_modules = nixpkgs.stdenv.mkDerivation {
    name = "node_modules";

    src = nix-filter {
      root = ./.;
      include = [
        ./package.json
        ./package-lock.json
      ];
    };

    # HACK: break the nix sandbox so we can fetch the dependencies. This
    # requires Nix to have `sandbox = relaxed` in its config.
    __noChroot = true;

    configurePhase = ''
      # NPM writes cache directories etc to $HOME.
      export HOME=$TMP
    '';

    buildInputs = [ self.nodejs ];

    # Pull all the dependencies
    buildPhase = ''
      ${self.nodejs}/bin/npm ci
    '';

    # NOTE[z]: The folder *must* be called "node_modules". Don't ask me why.
    #          That's why the content is not directly added to $out.
    installPhase = ''
      mkdir $out
      mv node_modules $out/node_modules
    '';
  };

  # And finally build the frontend in its own derivation
  my-frontend = nixpkgs.stdenv.mkDerivation {
    name = "my-frontend";
    # Use the current folder as the input, without node_modules
    src = nix-filter {
      root = ./.;
      exclude = [
        ./.next
        ./node_modules
      ];
    };

    nativeBuildInputs = [ self.nodejs ];

    buildPhase = "npm run build";

    configurePhase = ''
      # Get the node_modules from its own derivation
      ln -sf ${self.node_modules}/node_modules node_modules
      export HOME=$TMP
    '';

    # TODO: move to different derivation
    doCheck = true;
    checkPhase = ''
      npm run test
    '';

    # This is specific to nextjs. Typically you would copy ./dist to $out or
    # something like that.
    installPhase = ''
      # Use the standalone nextjs version
      mv .next/standalone $out

      # Copy non-generated static files
      cp -R public $out/public

      # Also copy generated static files
      mv .next/static $out/.next/static

      # Re-link the node_modules
      rm $out/node_modules
      mv node_modules $out/node_modules

      # Wrap the script
      cat <<ENTRYPOINT > $out/entrypoint
      #!${nixpkgs.stdenv.shell}
      exec "$(type -p node)" "$out/server.js" "$$@"
      ENTRYPOINT
      chmod +x $out/entrypoint
    '';
  };
}; in self
```

## Example packaging a .NET project

For .NET, there is a tool called [nuget2nix](https://github.com/winterqt/nuget2nix) that is called to generate a `deps.nix` file, which is then passed to `nixpkgs.buildDotnetModule`‘s `nugetDeps` argument. So every time a dependency changes, don’t forget to call that tool again. Because most .NET developers are on Windows, they also don’t have the tool installed, so we wrote a CI step that would check that the file was up to date and push a fixup commit otherwise. Then we re-discovered that dependabot doesn’t have the same permissions and would fail. This dance was starting to get old pretty fast.

So here is the new solution: fetch the dependencies with `__noChroot = true` in one derivation, and then pass them into the main build:

```nix
# Fill these arguments how you like
{ nixpkgs ? import <nixpkgs> { } # an instance of nixpkgs
, nix-filter # an instance of https://github.com/numtide/nix-filter
}:
let self =
{
  # The .NET packages we want to use
  dotnet-sdk = nixpkgs.dotnetCorePackages.sdk_6_0;
  dotnet-runtime = nixpkgs.dotnetCorePackages.aspnetcore_6_0;

  # Fetch all the dependencies in one derivation with __noChroot = true
  nugetDeps = nixpkgs.stdenv.mkDerivation {
    name = "nuget-deps";

    # HACK: break the nix sandbox so we can fetch the dependencies. This
    # requires Nix to have `sandbox = relaxed` in its config.
    __noChroot = true;

    # Only rebuild if the project metadata has changed
    src = nix-filter {
      root = ./.;
      include = [
        (nix-filter.isDirectory)
        (nix-filter.matchExt "csproj")
        (nix-filter.matchExt "slnf")
        (nix-filter.matchExt "sln")
      ];
    };

    nativeBuildInputs = [
      nixpkgs.cacert
      self.dotnet-sdk
    ];

    # Avoid telemetry
    configurePhase = ''
      export DOTNET_NOLOGO=1
      export DOTNET_CLI_TELEMETRY_OPTOUT=1
    '';

    projectFile = "my-api.slnf";

    # Pull all the dependencies for the project
    buildPhase = ''
      for project in $projectFile; do
        dotnet restore "$project" \
          -p:ContinuousIntegrationBuild=true \
          -p:Deterministic=true \
          --packages "$out"
      done
    '';

    installPhase = ":";
  };

  # Build the project itself
  my-api = nixpkgs.buildDotnetModule {
    pname = "my-api";
    version = "0";

    src = nix-filter {
      root = ./.;
      exclude = [
        # Filter out C# build folders
        (nix-filter.matchName "bin")
        (nix-filter.matchName "logs")
        (nix-filter.matchName "obj")
        (nix-filter.matchName "pub")
        (nix-filter.matchName ".vs")
      ];
    };

    projectFile = "my-api.slnf";

    # Replace the `nugetDeps = ./deps.nix` with the derivation.
    # This is only possible for nixpkgs that contains this PR:
    # https://github.com/NixOS/nixpkgs/pull/178446
    nugetDeps = self.nugetDeps;

    dotnet-sdk = self.dotnet-sdk;
    dotnet-runtime = self.dotnet-runtime;

    executables = [
      "MyAPI"
    ];
  };
}
```

## Conclusion

So there you have it. I hope that the explanation and examples give you an idea of how to apply this in various contexts, and help unblock some packaging problems that you might have. It’s better to use Nix impurely than not at all, and the sandbox change is really localized and controlled.

Of course, if you want help with pure packaging, you can always reach out to [Numtide](https://numtide.com/contact) and we can help you out.

That’s all, hope this was interesting!
