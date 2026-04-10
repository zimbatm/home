# kin.nix: `users.migration-test` looks like a leftover

## What

`kin.nix:15`:
```nix
users.migration-test = { admin = true; uid = 1001; };
```

Name reads as a temporary account from a past migration exercise. No
ssh keys, no `recipientOnly`, no host config or module references it:

```sh
git grep -n migration-test -- . ':!gen/'
# → kin.nix:15 only
```

`gen/manifest.lock` carries a `users/password-migration-test/_shared`
entry, so it's materialised as a real admin (wheel) unix account on all
3 machines.

## Why

If it's done its job: −1 line in kin.nix, −1 admin account on every
host, −1 `gen/users/*` secret to manage. Fewer wheel users on
public-facing web2/relay1 is a small attack-surface win.

## Decision needed (Jonas)

Is `migration-test` still load-bearing for an in-flight kin/userborn
migration test? Grep can't see interactive ssh logins.

- **If done** → delete `kin.nix:15`, run `kin gen` (drops
  `gen/users/password-migration-test/`), commit both. Deploy picks up
  the removal; userborn tombstones uid 1001.
- **If still needed** → add a trailing `# until <what>` comment so the
  next simplifier round skips it.

## Blockers

needs-human — touches `kin.nix` (spine) and removes a deployed wheel
account. Do NOT auto-drop; requires `kin gen` + human-gated deploy.
