---
name: kin-opts
description: Query this fleet's evaluated NixOS option tree before writing option paths. Use whenever you're about to set or reference an option in machines/ or modules/ and aren't certain the path exists — it returns the merged value, type, and which file set it.
---

Before writing any `services.*` / `programs.*` / `kin.*` / etc. option path in
`machines/<host>/configuration.nix` or `modules/nixos/*.nix`, confirm it exists
on the target host:

```sh
kin-opts <host> <option.path>     # leaf → {value,type,description,declared,defined}
                                  # non-leaf → {children:[...]} to drill down
kin-opts <host> --search <regex>  # full-tree path grep (kin/maille/local included)
kin-opts --hosts                  # nv1 web2 relay1
```

`defined` shows which file in *this* repo (or kin/srvos) actually set the
value — generic nixpkgs docs can't tell you that. If the lookup errors, the
path is wrong; `--search` or drill from a parent before guessing again.
