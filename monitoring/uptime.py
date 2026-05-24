#!/usr/bin/env python3
"""Declarative Better Stack uptime monitors + reconcile.

Run: nix run --offline nixpkgs#python3 -- monitoring/uptime.py        # preview
     nix run --offline nixpkgs#python3 -- monitoring/uptime.py --apply  # create

Reads BETTERSTACK_API_KEY from env. Idempotent on friendly_name
(pronounceable_name). Existing monitors with names not in DESIRED are left
alone — manage those via the web UI.
"""
import json, os, sys, urllib.request, urllib.error

API = "https://uptime.betterstack.com/api/v2"
KEY = os.environ["BETTERSTACK_API_KEY"]

# Each entry: (pronounceable_name, monitor_type, url, **extras)
DESIRED = [
    # Public web (HTTP status; status type implies just 2xx is fine)
    ("zimbatm.com",         "status",  "https://zimbatm.com/"),
    ("gts.zimbatm.com",     "keyword", "https://gts.zimbatm.com/api/v1/instance",
       {"required_keyword": "gts.zimbatm.com"}),
    ("mail.zimbatm.com",    "keyword", "https://mail.zimbatm.com/",
       {"required_keyword": "Stalwart"}),
    ("mail.ztm.io",         "keyword", "https://mail.ztm.io/",
       {"required_keyword": "snappymail"}),
    ("mta-sts policy",      "keyword", "https://mta-sts.zimbatm.com/.well-known/mta-sts.txt",
       {"required_keyword": "STSv1"}),

    # Wire-level mail ports (BS wants `port` as a separate numeric field)
    ("mail SMTP/25",        "tcp", "mail.zimbatm.com", {"port": 25}),
    ("mail IMAPS/993",      "tcp", "mail.zimbatm.com", {"port": 993}),
    ("mail submission/465", "tcp", "mail.zimbatm.com", {"port": 465}),

    # Internal-ish services on ztm.io
    ("chat weechat relay",  "tcp", "chat.ztm.io",    {"port": 9443}),  # TLS relay; 9001 plaintext was retired
    ("agents ssh",          "tcp", "agents.ztm.io",  {"port": 22}),
    # mc minecraft (mc.ztm.io:25565) skipped — Better Stack free tier caps at 10 monitors.
]


def api(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        f"{API}{path}", data=data, method=method,
        headers={
            "Authorization": f"Bearer {KEY}",
            "Content-Type": "application/json",
        },
    )
    try:
        return json.load(urllib.request.urlopen(req, timeout=15))
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code}: {e.read().decode(errors='replace')}")


def fetch_monitors():
    out = {}
    page = 1
    while True:
        r = api("GET", f"/monitors?page={page}")
        for m in r.get("data", []):
            out[m["attributes"]["pronounceable_name"]] = m
        if not r.get("pagination", {}).get("next"):
            break
        page += 1
    return out


def build_body(entry):
    name, mtype, url = entry[0], entry[1], entry[2]
    extras = entry[3] if len(entry) > 3 else {}
    body = {"monitor_type": mtype, "url": url, "pronounceable_name": name}
    body.update(extras)
    return body


def main():
    apply = "--apply" in sys.argv
    existing = fetch_monitors()
    create, keep = [], []
    for entry in DESIRED:
        if entry[0] in existing:
            keep.append(entry[0])
        else:
            create.append(build_body(entry))

    print(f"=== existing ({len(existing)} total in Better Stack) ===")
    for n in sorted(existing): print(f"  - {n}")
    print(f"\n=== keep ({len(keep)}) ===")
    for n in keep: print(f"  ✓ {n}")
    print(f"\n=== create ({len(create)}) ===")
    for c in create:
        extras = {k: v for k, v in c.items() if k not in ("pronounceable_name", "monitor_type", "url")}
        print(f"  + {c['pronounceable_name']:25}  type={c['monitor_type']:8}  url={c['url']}  {extras if extras else ''}")

    if not apply:
        print("\n(dry-run — pass --apply to create)")
        return 0

    for c in create:
        print(f"\ncreating {c['pronounceable_name']}…")
        r = api("POST", "/monitors", c)
        mid = r.get("data", {}).get("id", "?")
        print(f"  → id={mid}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
