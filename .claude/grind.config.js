export const meta = {
  name: 'home-grind',
  description: 'Dogfood-repo grind: drift-check, simplify, bump inputs, scout external tooling; gate = all hosts eval+build',
  whenToUse: 'When the user wants autonomous progress on the home fleet config',
  phases: [
    { title: 'Triage', detail: 'pick items; drift-check first if stale' },
    { title: 'Work', detail: 'implementers + 1 rotating specialist' },
    { title: 'Merge', detail: 'serialized; eval + dry-build all hosts' },
    { title: 'Meta', detail: 'audit; deploy-reminder if hosts changed' },
  ],
}

const HOSTS = ['nv1', 'relay1', 'web2']

const CONFIG = {
  name: 'home',
  implementers: 2,
  archCadence: 6,
  fastCheck: `nix eval .#nixosConfigurations --apply builtins.attrNames && \
    for h in ${HOSTS.join(' ')}; do nix build .#nixosConfigurations.$h.config.system.build.toplevel --dry-run --quiet || exit 1; done`,

  triageExtra: () => `
   **kin.nix is the spine** — at most 1 pick per round that touches it.
   ops-* items (deploy, kin set) are human-in-the-loop; mark "needs-human"
   instead of picking.`,

  mergeGate: () => ({
    needsGate: true,
    cmd: CONFIG.fastCheck,
    instructions: `All ${HOSTS.length} hosts must eval and dry-build clean. If a host
fails, the change broke that machine's config — abandon, don't partially merge.`,
  }),

  metaExtra: () => `
If any \`machines/\` or \`kin.nix\` was touched this round, remind: changes
are committed but NOT deployed. \`kin deploy <machine>\` to actually
apply (with the deploy-safety check from feedback_deploy_safety.md).`,

  specialists: {
    drift: ctx => `${ctx.BASE_SETUP}
You are the DRIFT-CHECKER. Compare what's declared vs what's deployed.

For each host in ${HOSTS.join(' ')}: \`kin status <host>\` (or
\`ssh <host> readlink /run/current-system\` vs the local toplevel).
File backlog/drift-<host>.md for any mismatch with the diff and a
proposed reconciliation (usually: just deploy, but flag if deployed
state has something declared doesn't).

Also check: are flake.lock inputs >30 days stale? File backlog/bump-*.
${ctx.MAIN_GUARD}`,

    simplifier: ctx => `${ctx.BASE_SETUP}
You are the SIMPLIFIER. This is a 38-line kin.nix + ~1500 LoC total —
keep it that way.

- modules/ files not imported by any host → delete
- commented-out config (zerotier, tailscale leftovers) → delete
- inputs in flake.nix not referenced → drop + relock
- per-host config that's identical across hosts → lift to common.nix
${ctx.MAIN_GUARD}`,

    bumper: ctx => `${ctx.BASE_SETUP}
You are the BUMPER. Update one input per round and prove it builds.

\`nix flake update <input>\` for the oldest-locked input. Then run
fastCheck. If a host breaks, investigate (changelog, error) and either
fix or file backlog/bump-<input>-blocked.md with the reason.

Priority: nixpkgs > kin > iets > others. Don't bump >1 input per round
(blast radius).
${ctx.MAIN_GUARD}`,

    scout: ctx => `${ctx.BASE_SETUP}
You are the SCOUT. Survey the outside world for LLM/agent tooling worth
trying on nv1 (the LLM-future testbed) and file backlog/adopt-* sketches.

Sources (curl via Bash; no WebSearch tool here):
- \`curl -sL https://raw.githubusercontent.com/Mic92/dotfiles/main/home-manager/modules/ai.nix\`
- \`curl -sL https://raw.githubusercontent.com/nix-community/awesome-nix/master/README.md | grep -iA1 'llm\\|whisper\\|voice\\|agent'\`
- \`gh search prs --repo nixos/nixpkgs --label '6.topic: AI/ML' --merged --limit 20 --json title,url 2>/dev/null\`

For each promising find: file \`backlog/adopt-<slug>.md\` (what / why /
how-much / falsifies). Frame as "X does Y; here's our angle on the same
problem" — Jonas wants original work, not verbatim copies. Skip anything
already in backlog/, tried/, or wontfix/. Max 2 filings per round.
${ctx.MAIN_GUARD}`,
  },
}
