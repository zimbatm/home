# Deploy rotated fleet PKI (post leaked-key rotation)

**Status (2026-04-10):** rotation done — `kin gen --rotate all` + fresh
migration-test keypair landed. Leaked key (`age17v8f…ugymsk04maf`, in
git history `b3d410d..73b86c7`) verified locked out of all 14 `.age`
files. Gate GREEN 3/3. **Deploy remaining.**

**What's left (human):** `kin deploy nv1 relay1 web2`

This applies: new fleet-id + ULA prefix, new SSH+TLS CA, new host keys
for all 3, new mesh fingerprints, new passwords for
zimbatm/migration-test/claude, and the `users.claude` authorized_key
from `4fca942`.

**After deploy:**
- New zimbatm sudo password: `age -d -i <your-key>
  gen/users/password-zimbatm/_shared/plain.age` (rotate again from a
  non-logged shell if paranoid — current value passed through agent
  transcript).
- Close this + `ops-grind-fleet-access.md`.
- Optional: `git filter-repo` history scrub of the old `.key` (low
  value — assume scraped; rotation is the real fix).

**Falsifies:** post-deploy, `age -d -i /tmp/leaked-migration-test.key
gen/identity/ca/_shared/ssh-ca.age` still fails; `ssh
claude@95.216.188.155 true` exits 0.
