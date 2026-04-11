# bug: crush go-modules FOD 401s on artifactory GOPROXY

`inputs.llm-agents.packages.….crush` build fails:
`crush-0.56.0-go-modules` FOD → `artifactory.infra.ant.dev/.../@v/*.zip: 401`.

A sandboxed FOD shouldn't see host `GOPROXY`. Either the derivation
sets it explicitly (check llm-agents source), or there's a
`nix.conf`/netrc leak on this build host.

**Dropped from `modules/home/desktop/default.nix` to unblock @all
deploy** (assise:// rotate). Restore once root-caused.

## Investigate

- `nix derivation show .#…crush.goModules | jq '.[].env.GOPROXY'`
- If unset there: check `/etc/nix/nix.conf` `impure-env`, build-host
  `~/.config/go/env`, whether the FOD has `__impure = true`.
