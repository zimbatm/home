# Self-hosted Bluesky PDS (pds.zimbatm.com)

Runs `services.bluesky-pds` (nixpkgs module) on **web2**, fronted by nginx at
`https://pds.zimbatm.com`. Holds zimbatm's AT Protocol repo + blobs. The
account (`did:plc:wxnofyouho6vcuevbvocutid`, handle `@zimbatm.com`) was
**migrated** here from bsky.social — same DID, so the `_atproto.zimbatm.com`
TXT record and the social graph were preserved; only the PDS endpoint and the
signing/rotation keys inside the DID document changed.

Defined in:
- `modules/nixos/bluesky-pds.nix` — service + nginx vhost
- `machines/web2/configuration.nix` — imports the module, restic-backs `/var/lib/pds`
- `secrets/web2-bluesky-pds.age` — env file (see below)
- `dns/dnsconfig.js` — `pds` A/AAAA → web2; `_atproto` TXT (the DID claim)

## Secrets

`secrets/web2-bluesky-pds.age` is an env file loaded via `environmentFiles`:

| var | how to generate |
|---|---|
| `PDS_JWT_SECRET` | `openssl rand -hex 16` |
| `PDS_ADMIN_PASSWORD` | `openssl rand -hex 16` — used by `pdsadmin` |
| `PDS_PLC_ROTATION_KEY_K256_PRIVATE_KEY_HEX` | `openssl ecparam --name secp256k1 --genkey --noout --outform DER \| tail --bytes=+8 \| head --bytes=32 \| od -An -v -tx1 \| tr -d ' \n'` |
| `PDS_EMAIL_SMTP_URL` | `smtps://zimbatm@zimbatm.com:APP_PASSWORD@smtp.fastmail.com:465/` (Fastmail app password) — needed for email confirmation + PLC tokens |

⚠️ **The PLC rotation key controls the identity.** It is the recovery key for
the DID — losing it (and all other rotation keys in the PLC log) means losing
control of the account. It lives in agenix + the web2 restic backup; keep both.

Edit with `agenix -e secrets/web2-bluesky-pds.age` (run from the repo on nv1).

## Admin

`pdsadmin` and `goat` are on web2's PATH (run as root):

```bash
ssh root@web2 pdsadmin create-invite-code
ssh root@web2 pdsadmin help
```

## Phase 2 — migrating an existing bsky.social account here

Done once, interactively, with `goat`. The DID is preserved. Outline (confirm
exact subcommands against `goat account --help` on the installed version):

1. **Prereqs:** a bsky app password (bsky.social → Settings → App Passwords),
   an invite code (`pdsadmin create-invite-code`), the new PDS admin password,
   and access to the account's email (Fastmail) for the PLC token.
2. **Move data:** `goat account login` to the *old* PDS, then
   `goat account migrate` → creates a deactivated account on pds.zimbatm.com,
   imports the repo (posts), copies blobs, copies preferences.
3. **Move identity (the irreversible-ish step):** request a PLC token
   (old PDS emails it), then sign + submit a PLC operation repointing the DID
   to pds.zimbatm.com with the new rotation/verification keys.
4. **Activate:** activate the account on pds.zimbatm.com; the old one
   deactivates. Set the primary handle to `zimbatm.com` (DNS TXT already set).
5. **Verify:**
   ```bash
   curl -s https://pds.zimbatm.com/xrpc/_health
   curl -s https://plc.directory/did:plc:wxnofyouho6vcuevbvocutid | jq .service
   # serviceEndpoint should now be https://pds.zimbatm.com
   ```

**Safety net:** did:plc has a ~72h recovery window via rotation keys, and the
old account is *deactivated, not deleted* — so a botched migration can be
rolled back as long as the rotation key is intact.

## DNS push

After editing `dns/dnsconfig.js`: `nix run .#dns-preview` then `.#dns-push`
(see [dns.md](dns.md)).
