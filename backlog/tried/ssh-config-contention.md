# ~/.ssh/config contention with sibling fleets — resolved

Agent-only path (cert in ssh-agent) is sufficient for kin ssh/deploy.
The Host-block-in-~/.ssh/config approach (tried @ feef522, re-added
post-clobber, removed @ this commit) creates overlap with kin-infra's
config writer. Don't re-add it.

Durable fix filed cross-repo: ../kin/backlog/feat-ssh-opts-identity.md

---

## 2026-04-12 — agent-only verdict invalidated: identity file clobbered

drift @ b1e05ae: `kin status` 3/3 unreachable (relay1+web2 publickey
denied, nv1 not-on-mesh). Regression from f0981d9 where 3/3 were
probeable. Root cause: `~/.ssh/id_ed25519{,-cert.pub}` was overwritten
2026-04-12 03:42 by sibling kin-infra runner-reseed (cert Key ID
`assise://dwqfzbq5…/user/claude#runner-reseed`, signing CA
`SHA256:19wpMsGzu…`). No cert signed by home CA
`SHA256:K8GPw7x…` (`bir7vyhu…`) remains on the worker; ssh-agent
held only git-signing + kin-infra keys.

So "agent-only suffices" above held only while the home cert survived in
the default identity slot. kin-infra writes both `~/.ssh/kin-infra_ed25519`
(namespaced) *and* `~/.ssh/id_ed25519` (default) — the second write
evicts whatever home put there.

**Don't retry:** loading the kin-infra cert into ssh-agent (tried this
round) — wrong CA, server rejects it.

**Durable fix is now load-bearing**, not nice-to-have: kin needs
per-fleet `IdentityFile` (e.g. `~/.ssh/kin-<fleet>_ed25519`) so
sibling fleets on a shared worker can't evict each other. Re-cross-filed
`../kin/backlog/feat-ssh-per-fleet-identity.md` (prior
feat-ssh-opts-identity.md no longer present in ../kin/backlog/).
