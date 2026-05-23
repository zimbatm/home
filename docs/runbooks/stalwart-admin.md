# Stalwart admin API

Stalwart's admin REST lives at `http://127.0.0.1:8485/api/...` (mail-only, no
public exposure). nginx proxies it at `https://mail.zimbatm.com/admin` for
the browser UI.

## Credentials

```bash
ssh root@mail.zimbatm.com 'cat /run/agenix/stalwart-admin-secret'
```

Username is `admin`.

## Create a domain (must exist before any principal in it)

```bash
ADMIN=$(ssh root@mail.zimbatm.com 'cat /run/agenix/stalwart-admin-secret')
curl -sS -u "admin:$ADMIN" -X POST \
  https://mail.zimbatm.com/api/principal \
  -H 'Content-Type: application/json' \
  --data '{
    "type": "domain",
    "name": "example.com",
    "description": "Optional human label"
  }'
```

Response: `{"data": <id>}`. If you skip this step and try to create a
principal first, you'll get `{"error":"notFound","item":"example.com"}` —
because Stalwart can't find the parent domain.

## Create an individual (user/mailbox)

```bash
PW=$(head -c 64 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c 32)
curl -sS -u "admin:$ADMIN" -X POST \
  https://mail.zimbatm.com/api/principal \
  -H 'Content-Type: application/json' \
  --data "{
    \"type\": \"individual\",
    \"name\": \"alice@example.com\",
    \"emails\": [\"alice@example.com\"],
    \"secrets\": [\"$PW\"],
    \"roles\": [\"user\"]
  }"
```

Capture `$PW` — store it in agenix (e.g. `stalwart-alice-password.age`) and
hand it to the user out-of-band.

## List principals / domains

```bash
curl -sS -u "admin:$ADMIN" \
  'https://mail.zimbatm.com/api/principal?types=individual,domain' \
  | jq .
```

## DAV collections

DAV principals are auto-created the first time a client (vdirsyncer,
Thunderbird, mail.ztm.io webmail, …) hits `/dav/cal/<user>/` or
`/dav/card/<user>/`. The `default` collection appears as soon as the user
authenticates.

## Reset a password

```bash
curl -sS -u "admin:$ADMIN" -X PATCH \
  https://mail.zimbatm.com/api/principal/alice@example.com \
  -H 'Content-Type: application/json' \
  --data "{\"secrets\": [\"$NEW_PW\"]}"
```

## Common API quirks

- Settings stored in Stalwart's DB take precedence over the file-config we
  push via NixOS. Once a setting key exists in the DB (e.g. `tracer.journal.level`),
  editing the Nix value won't change it on a deploy — Stalwart logs a
  warning at boot.
- The settings API JSON schema isn't well-documented; expect
  `{"error":"about:blank","status":400,"detail":"JSON deserialization failed"}`
  for non-trivial schema mistakes. Use a fresh tracer ID rather than editing
  an existing one to bypass.
