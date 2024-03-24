{ inputs, self, ... }:
{
  perSystem = { system, ... }: {
    packages.docs = inputs.mkdocs-numtide.lib.${system}.mkDocs {
      name = "zimbatm-docs";
      src = self;
    };

    devshells.default.packages = [
      inputs.mkdocs-numtide.packages.${system}.default
    ];
  };
}
