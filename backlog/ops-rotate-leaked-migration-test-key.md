# Rotate all secrets — migration-test.key was committed

**What:** `keys/users/migration-test.key` (`AGE-SECRET-KEY-…` private
identity) was tracked in git from `b3d410d` (2026-04-06) until removed.
It is a recipient on every `gen/**/*.age` secret. Repo is public
(`github.com:zimbatm/dotfiles`). Assume the key — and therefore every
current secret plaintext — is compromised.

**Why:** Anyone who cloned/forked in that window can decrypt: fleet CA
private keys (ssh+tls), all 3 host ssh+tls private keys, and password
plaintext for zimbatm/migration-test/claude.

**How much:**
1. Decide `migration-test` fate:
   - **drop**: remove `users.migration-test` from kin.nix +
     `keys/users/migration-test.pub`. Grind container then needs the
     claude age private key (at `keys/users/claude.key` or
     `~/.config/kin/identity`, gitignored) to run `kin gen`.
   - **keep**: `age-keygen -o keys/users/migration-test.key` (fresh
     pair; `.key` stays local per gitignore), commit only the new `.pub`.
2. `kin gen --rotate all` — new plaintext for everything.
3. Commit `gen/` (+ any `keys/users/*.pub` change). Verify
   `git ls-files '*.key'` is empty.
4. `kin deploy nv1 relay1 web2` — CA + host keys changed.
5. Optional history scrub (`git filter-repo --invert-paths --path
   keys/users/migration-test.key` + force-push). Low value — assume
   already scraped; rotation is the real fix.

**Blockers:** needs-human — deploy, key-trust decision, possible
force-push.

**Falsifies:** post-rotation, `age -d -i <old-key>
gen/identity/ca/_shared/ssh-ca.age` fails with "no identity matched".
