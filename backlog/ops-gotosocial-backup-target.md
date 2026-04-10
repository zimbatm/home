# gotosocial has no backup target

**What:** Pick a new backup destination for `/var/lib/gotosocial` on web2
and wire restic (or equivalent) at it.

**Why:** The Hetzner storagebox (`u351392.your-storagebox.de`) no longer
exists (confirmed 2026-04-10). The CIFS mount + restic job + both
`gen.gotosocial-*` blocks were removed to unblock relay1/web2 eval.
gotosocial now has **no off-host backup**.

**How much:** Decide target (rsync.net? another storagebox? B2?), add a
`gen.*` block for creds, re-add `services.restic.backups.gotosocial`
pointing at it, `kin set` + `kin gen` + `kin deploy web2`.

**Cleanup while here:** `gen/user/gotosocial-restic-password/` is
orphaned (declaration removed, `kin gen` not yet run from a shell with
kin on PATH) — `kin gen` should prune it, or `git rm -r` if not.

**Blockers:** human picks the target + holds the creds.
