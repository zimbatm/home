# adopt: ask-local `diff-gate` — local risky-diff triage (our coderabbit)

## seed

Mic92's ai.nix now pulls `aiTools.coderabbit-cli` — cloud PR review from
the terminal. Scout e473c5a skipped it: "cloud review, ask-local too
small to counter **yet**." Since that skip three things landed here:
`--agent` bounded ReAct (07b2b2f), `--fast` lookup-decode (85d68cd), and
bench-agent.jsonl. The "yet" has a measurable delta now; re-open with a
narrower target.

## our angle

Don't try to *be* a reviewer — 3.8B on Arc won't out-review a cloud
model. Be the **gate in front of one**. coderabbit/any-cloud-review is
the expensive call; the local question is binary: *does this diff need
it?*

`git diff | ask-local --diff-gate` → GBNF-constrained JSON
`{risk: low|high, why: "<≤80 chars>"}` → exit 0/1. Same `--grammar`
path that voice-intent uses, so output is never malformed and
lookup-decode acceptance stays high (near-zero-entropy schema, cf.
adopt-lookup-decode premise). Hook it three places:

- pre-commit: `high` → print `why`, suggest llm-router review path
- llm-router: complexity-gate for the `/review` route — `low` diffs get
  ask-local's one-line summary, `high` escalates to cloud
- starship segment via agent-meter: dirty-tree risk glyph

## how much

~0.3r. Zero new inputs — `git` + ask-local already composed. New code:
one grammar file, ~20-line verb in ask-local dispatching `--diff-gate`
→ prefill template (diff capped at ~6k chars, hunk-header-weighted) →
existing `--grammar --fast` path. Hook wiring is modules/home/terminal.

## falsifies

- **3.8B risk-triage precision at hook latency**: hand-label last 50
  `home` commits as needed-review/didn't (the lockout-recovery-adjacent
  ones, the flake.lock-only ones). Target: ≥0.8 recall on needed-review
  at <2s p95 on Arc. Below that, the gate is noise and llm-router's
  complexity heuristic stays size-based (diff linecount), not
  model-based — which is the actual decision this buys.
- **grammar×lookup on diff-shaped prefill**: lookup-decode was benched
  on intent text; diffs are repetitive (context lines) → draft
  acceptance should be *higher*. If it isn't, the `--fast` win is
  narrower than ca52c59 assumed.

## blockers

None. Label set + latency bench gated on ops-deploy-nv1 like every
ask-local measurement.
