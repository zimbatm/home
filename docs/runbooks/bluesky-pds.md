# Self-hosted Bluesky PDS (pds.zimbatm.com)

Runs `services.bluesky-pds` (nixpkgs module, `pds-0.4.219`) on **web2**, fronted
by nginx at `https://pds.zimbatm.com`, listening on `127.0.0.1:3000`. Holds
zimbatm's AT Protocol repo + blobs.

The account (`did:plc:wxnofyouho6vcuevbvocutid`, handle `@zimbatm.com`) was
migrated here from bsky.social. The DID is unchanged, so followers/posts and the
`_atproto.zimbatm.com` TXT claim were preserved; only the PDS endpoint and the
keys in the DID document moved. It federates into the main network via the
default relay (`bsky.network`) and AppView (`api.bsky.app`), so you keep using
the regular Bluesky app — log in as `@zimbatm.com` with the **account** password.

Defined in:
- `modules/nixos/bluesky-pds.nix` — service + nginx vhost + the clan-vars env file
- `machines/web2/configuration.nix` — imports the module; `/var/lib/pds` is
  offsite-backed via `clan.core.state.bluesky-pds.folders` (clan borgbackup)
- `dns/dnsconfig.js` — `pds` A/AAAA → web2; `_atproto` TXT (the DID claim)

`pdsadmin` and `goat` are on web2's PATH (run as root). Deploys go through clan:
`clan machines update web2` (from nv1), or `nixos-rebuild switch --flake .#web2
--target-host root@web2.ztm.io` once a host holds the agent-deploy key.

---

## Secrets — the `web2-bluesky-pds` clan var

A multiline env file (`environmentFiles`), one `KEY=value` per line, decrypted to
`/run/secrets/vars/web2-bluesky-pds/value`. Four variables:

| var | notes |
|---|---|
| `PDS_JWT_SECRET` | `openssl rand -hex 16` |
| `PDS_ADMIN_PASSWORD` | `openssl rand -hex 16` — for `pdsadmin`, **not** account login |
| `PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX` | the identity recovery key (see below) |
| `PDS_EMAIL_SMTP_URL` | `smtps://zimbatm@zimbatm.com:APP_PASSWORD@smtp.fastmail.com:465/` (Fastmail app password). **Required** because `PDS_EMAIL_FROM_ADDRESS` is set in the module — the PDS demands both-or-neither, and a missing SMTP URL crash-loops the service (see Troubleshooting). |

Edit (re-prompts for the whole multiline value — paste **all four** lines):

```bash
# on nv1, from the repo
clan vars generate web2 --generator web2-bluesky-pds --regenerate
# …or:  clan vars set web2 web2-bluesky-pds/value
clan machines update web2
```

⚠️ **The PLC rotation key controls the identity.** It is the recovery key for the
DID — losing it (and every other rotation key in the PLC log) means permanently
losing control of `@zimbatm.com`. It lives in the clan var (committed encrypted)
+ the web2 borg backup. Keep both recoverable, ideally one copy offline.

---

## Day-2 operations

### Health check

```bash
curl -s https://pds.zimbatm.com/xrpc/_health                 # {"version":"0.4.219"}
ssh root@web2 systemctl status bluesky-pds                    # active (running)
# account is active and serving from this PDS:
curl -s "https://pds.zimbatm.com/xrpc/com.atproto.sync.getRepoStatus?did=did:plc:wxnofyouho6vcuevbvocutid"
# network sees it (handle resolves, follower/post counts populated):
curl -s "https://public.api.bsky.app/xrpc/app.bsky.actor.getProfile?actor=zimbatm.com" | jq '{handle,did,followersCount,postsCount}'
```

### Admin (`pdsadmin`, as root on web2)

```bash
pdsadmin help
pdsadmin create-invite-code
pdsadmin account list
pdsadmin account reset-password did:plc:wxnofyouho6vcuevbvocutid   # prints a fresh password
```

### App passwords

For third-party clients. Easiest: the Bluesky app → Settings → Privacy and
security → App passwords. Or against the PDS directly:

```bash
ACCESS=$(curl -s -X POST https://pds.zimbatm.com/xrpc/com.atproto.server.createSession \
  -H 'Content-Type: application/json' \
  -d '{"identifier":"zimbatm.com","password":"FULL_ACCOUNT_PASSWORD"}' | jq -r .accessJwt)
curl -s -X POST https://pds.zimbatm.com/xrpc/com.atproto.server.createAppPassword \
  -H "Authorization: Bearer $ACCESS" -H 'Content-Type: application/json' \
  -d '{"name":"my-client","privileged":false}' | jq    # privileged:true for DM access
# list / revoke: com.atproto.server.{listAppPasswords,revokeAppPassword}
```

### Backups (clan borgbackup → rsync.net)

Repo `zh6422@zh6422.rsync.net:zimbatm-home-borg/web2`, encrypted. One daily
archive at 01:00 (`borgbackup-job-rsync-net.timer`) covering the union of web2's
`clan.core.state.*.folders`, which includes `/var/lib/pds`.

```bash
# on web2 (the borg-job wrapper sets repo + passphrase + rsh):
borg-job-rsync-net list                 # archives
borg-job-rsync-net info
systemctl start borgbackup-job-rsync-net.service   # manual run (run this right after any migration/restore)
# restore: clan backups list/restore web2  (from nv1), or borg-job-rsync-net extract '::ARCHIVE' path
```

⚠️ Restoring needs the **borg passphrase** (clan var `rsync-net-…` / borg key) —
verify it's recoverable from the clan-vars repo independently of web2. A
`borg key export` stored offline is good insurance.

### Federation / relay — the `request-crawl` gotcha

The AppView only sees you if the `bsky.network` relay is crawling this PDS. The
PDS asks for this automatically on activation (`PDS_CRAWLERS`), but after a
migration or any account (de)activation the relay can hold a stale state — the
symptom is `getLatestCommit` returning `RepoDeactivated` while the PDS itself
reports `active: true`, and an empty AppView profile. Fix:

```bash
ssh root@web2 pdsadmin request-crawl bsky.network
# then re-check getLatestCommit (should return a cid) and the AppView profile
```

### Identity / disaster recovery

- `did:plc` has a ~72h rotation-key recovery window; the `PDS_PLC_ROTATION_KEY…`
  above is the key. Inspect/manage the DID with `goat account plc …`.
- After a full restore of `/var/lib/pds`, run a `request-crawl` so the relay
  re-indexes.

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `502 Bad Gateway` from nginx | `bluesky-pds` not serving on :3000 — `journalctl -u bluesky-pds`. |
| Log: `Partial email config, must set both emailFromAddress and emailSmtpUrl` | `PDS_EMAIL_SMTP_URL` missing from the clan var — add it (see Secrets). |
| `getLatestCommit` → `RepoDeactivated` but PDS says active | relay not crawling — `pdsadmin request-crawl bsky.network`. |
| App login `401 Invalid identifier or password` | using the admin password instead of the account password, or a mangled value — `pdsadmin account reset-password`. |

## DNS push

After editing `dns/dnsconfig.js`: `nix run .#dns-preview` then `.#dns-push`
(see [dns.md](dns.md)).
