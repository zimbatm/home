# DNS via dnscontrol

All three Namecheap-hosted zones (`zimbatm.com`, `ztm.io`, `chevalier.sh`) are
declared in `dns/dnsconfig.js`. Edit that file → preview → push. No web UI.

## Preview

```bash
nix run .#dns-preview
```

Reads the API for current state, compares to the file. The two "INFO: Zone
does not exist. Can not create because 'namecheap' does not implement
ZoneCreator" lines are harmless dnscontrol noise — the zones obviously exist
or you wouldn't have records there.

Look for `CREATE`, `MODIFY`, `DELETE` in the output. Anything red means
divergence.

## Push

```bash
nix run .#dns-push
```

Idempotent. Re-running after a successful push produces no diff (except the
harmless zone-creator INFOs).

## Add a new subdomain

```js
var FOO_A    = "1.2.3.4";
var FOO_AAAA = "2001:db8::1";

D("ztm.io", REG_NC, DnsProvider(DNS_NC),
  // …existing records…
  A("foo",    FOO_A),
  AAAA("foo", FOO_AAAA),
);
```

Then `nix run .#dns-push`.

## Credentials

`dns-preview` / `dns-push` build a `creds.json` at runtime from env vars set
in `.envrc.local`:

```
NAMECHEAP_API_USER=…
NAMECHEAP_API_KEY=…
```

Namecheap requires the source IP to be whitelisted in their API panel.

## Editing existing records

dnscontrol diffs by **(name, type)**: change the value, push. To rename or
remove a record, edit/delete the line and push — dnscontrol issues a DELETE.

## TTL

`DefaultTTL(1800)` at the top of each zone block. Override per-record with
`TTL(300)` as a third arg to `CNAME(...)` etc.

## What lives where

| zone | role |
|---|---|
| `zimbatm.com` | work-ish/public identity, MX on Fastmail; `pds` → self-hosted Bluesky PDS |
| `ztm.io` | internal services (chat, mail, agents, mc) |
| `chevalier.sh` | personal/family identity, MX on Fastmail |
