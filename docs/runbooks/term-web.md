# Web terminal at https://agents.ztm.io/

ttyd behind nginx (mTLS) on the `agents` box. Image-paste preserved via
xterm.js's iTerm2 OSC 1337 addon (no tmux/herdr-style escape mangling in
the browser path).

## Issue a client cert for a new device

```bash
cd ~/go/src/github.com/zimbatm/home
nix shell nixpkgs#openssl nixpkgs#age -c ./pki/issue.sh client <name>   # e.g. p1, phone, ipad
```

Writes `pki/clients/<name>.p12` and prints a one-time password. The CA
private key is age-decrypted from `pki/term-ca.key.age` using your nv1
age key (`~/.config/sops/age/keys.txt`) only for the duration of the
sign — never persists.

**No server-side change is needed** when adding a client. The CA cert
(`pki/term-ca.crt`) is baked into the agents nginx config at build time
and trusts any cert signed by it.

## Install the certs in a browser

Two imports are needed per device — the **CA cert** (so the browser
trusts the server) and the **client cert** (so the server trusts the
browser). Both certs are signed by the same CA at `pki/term-ca.crt`;
we don't use Let's Encrypt or any public CA on this surface.

**Firefox**: Preferences → Privacy & Security → Certificates → View
Certificates.
- *Authorities* tab → Import → pick `pki/term-ca.crt` → tick "Trust
  this CA to identify websites".
- *Your Certificates* tab → Import → pick `pki/clients/<name>.p12` →
  enter the printed password.

**Chromium**: `chrome://settings/security` → Manage certificates →
import `pki/term-ca.crt` under *Authorities* and `pki/clients/<name>.p12`
under *Your Certificates*.

**Keychain (macOS / Safari)**: double-click `pki/term-ca.crt` → set it
to "Always Trust" for SSL in Keychain Access. Then double-click the
`.p12` and enter the password. Safari uses both automatically.

**Android**: Settings → Security → Encryption & credentials → Install a
certificate → CA certificate (`term-ca.crt`) and separately a VPN & app
user certificate (`.p12`).

Then visit https://agents.ztm.io/ — the browser prompts which client
cert to present.

## Revoke a lost cert

There's no CRL/OCSP wired up (you only have a handful of devices). Two
paths:

1. **Pin allowed CNs in nginx** (preferred if revoking once). Add to the
   `agents.ztm.io` vhost extraConfig:

   ```nginx
   if ($ssl_client_s_dn !~ "CN=(nv1|p1|phone)$") { return 403; }
   ```

   Edit the list, deploy. Revoked CN is now refused even with a valid
   cert.

2. **Roll the CA** if you've lost multiple certs or the CA key is
   suspect:

   ```bash
   rm pki/term-ca.crt pki/term-ca.key.age pki/clients/*
   ./pki/issue.sh ca
   ./pki/issue.sh client nv1   # + each device you still own
   ```

   Then deploy agents (nginx picks up the new CA) and re-import the new
   p12 in each browser. Old certs become useless instantly because they
   no longer chain to a trusted CA.

## Inside the session

The shell launched is `bash -l`, so the existing
`programs.bash.interactiveShellInit` on agents auto-execs herdr.
Detach: `Ctrl-b q` (default herdr binding). Closing the browser tab is
the same as detaching — reattach by reloading the page.

To bypass herdr for a session: `NO_HERDR=1` is honored, but you'd need
to invoke a wrapper that sets it — the ttyd entrypoint doesn't read it
from the URL. Easiest: just `exec bash` from inside herdr.

## Re-issue the server cert

If you need to change the FQDN or rotate the server key:

```bash
nix shell nixpkgs#openssl nixpkgs#age -c \
  ./pki/issue.sh server agents.ztm.io \
  'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAION9fEQJzwaGn7LzRiRWf9sGAU0hgRd2DtaMOm/DXr+F'
# then redeploy agents
```

The pubkey arg is the agents host's `ssh-ed25519` key (see
`secrets/secrets.nix` `agents = …`). The new cert is committed and the
key lands in `secrets/agents.ztm.io-server-key.age` — both git-tracked,
the latter age-encrypted.

## Cert renewal

- **CA cert**: 10-year validity from bootstrap (2026-05 → 2036-05).
  Calendar reminder for 2035.
- **Server cert**: also 10 years; no public-CA ceiling because we own
  the CA. Re-issue ahead of expiry.
- **Client certs**: 27 months from issue (under the 825-day Apple+Chrome
  ceiling that still applies because clients may present these to other
  contexts in theory). Re-issue with `./pki/issue.sh client <name>` and
  re-import.
