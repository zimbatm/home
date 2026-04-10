# Grind drift-checker has no fleet access

**Status (2026-04-10 @ 4fca942):** `users.claude` declared in kin.nix
(ssh key `…C1E6 claude@kin-infra` = `~/.ssh/kin_ed25519` on grind
runners). `kin gen` materialized password-claude + rekeyed. Gate GREEN.
Remaining: deploy.

**What's left (human):**
1. `kin deploy nv1 relay1 web2` — applies the new authorized_key (and
   the host-key rotation from `2a87efa`). After this, `kin status` from
   the grind container shows real toplevel hashes for relay1/web2.
2. nv1 (`fd18:cb0b:6a1d::…`) stays mesh-only and unreachable from the
   grind container even after deploy. Acceptable (desktop, often off) —
   or enroll the container as a maille member if nv1 drift matters.

**Falsifies:** post-deploy, `ssh -i ~/.ssh/kin_ed25519
claude@95.216.188.155 true` exits 0 from the grind container.

**History:** earlier re-checks (2026-04-08…04-10) recorded three
distinct keys observed across runners; `…C1E6` stabilised and is the
one enrolled. ssh config on the runner has the Host block + HostName
mappings.
