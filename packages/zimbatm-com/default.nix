{ pkgs, ... }:

# Builds the zimbatm.com static site. The builder is a small slice of kit's
# toolbox Python, vendored at ./builder so this repo doesn't depend on kit.
# Source content (notes + projects + templates) lives at ./data.
pkgs.runCommand "zimbatm-com"
  {
    src = ./.;
    nativeBuildInputs = [
      (pkgs.python3.withPackages (ps: [ ps.pyyaml ]))
    ];
  }
  ''
    mkdir -p $out
    # DataClient.find_data_dir() looks for ./data relative to CWD, so we
    # cd into $src first. We still pass the data dir explicitly to
    # ViewBuilder because ViewRenderer plumbs it through.
    cd $src
    python3 $src/builder/build.py zimbatm.com data $out
  ''
