# ~/.ssh/config contention with sibling fleets — resolved

Agent-only path (cert in ssh-agent) is sufficient for kin ssh/deploy.
The Host-block-in-~/.ssh/config approach (tried @ feef522, re-added
post-clobber, removed @ this commit) creates overlap with kin-infra's
config writer. Don't re-add it.

Durable fix filed cross-repo: ../kin/backlog/feat-ssh-opts-identity.md
