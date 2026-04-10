# Land users.claude deployer (parked on grind/add-claude-deployer)

**What:** Merge `grind/add-claude-deployer` to main: adds `users.claude`
(admin, ssh key = `~/.ssh/kin_ed25519`, same as kin-infra) +
`keys/users/claude.pub` age recipient. Unblocks drift-checker fleet
access (relay1/web2) once deployed.

**Why parked:** Declaring the user requires `kin gen` to materialize
`gen/users/password-claude/`, but at the current kin pin (88daf880)
`kin gen` rotates the **entire fleet PKI** — new CA, new host keys for
nv1/relay1/web2, new password hashes for zimbatm + migration-test. Root
cause: kin bumps since gen/manifest.lock (ba70ebd) changed generator
inputHashes. Filed `../kin/backlog/bug-gen-inputhash-rotates-on-bump.md`
(kin@409dbba).

**How to land — pick one:**
- (a) Wait for the kin fix, `nix flake update kin`, then `kin gen`
  (should only add password-claude + rekey), merge, `kin deploy`.
- (b) Accept the rotation now: checkout the branch, run
  `KIN_IDENTITY=keys/users/migration-test.key kin gen`, commit gen/,
  merge, `kin deploy nv1 relay1 web2` (all three — host keys changed).

**Blockers:** needs-human — PKI rotation decision + deploy.

**After merge:** also closes most of `ops-grind-fleet-access.md`.
