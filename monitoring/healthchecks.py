#!/usr/bin/env python3
"""Declarative healthchecks.io checks for cron-like systemd timers.

Run: nix run --offline nixpkgs#python3 -- monitoring/healthchecks.py        # preview
     nix run --offline nixpkgs#python3 -- monitoring/healthchecks.py --apply  # create

Needs HEALTHCHECKS_API_KEY in env. Idempotent on `name`. Prints each check's
ping URL after creation — paste those into the agenix secret used by the
restic-backups-<svc>.service ExecStopPost hook (see machines/<host>/).

Schedule: each restic timer fires daily with a 30-min random delay
(`OnCalendar=daily` + `RandomizedDelaySec=30m`), so we set a 25h timeout
+ 6h grace — only paged after ~31h of silence.
"""
import json, os, sys, urllib.request, urllib.error

API = "https://healthchecks.io/api/v3"
KEY = os.environ["HEALTHCHECKS_API_KEY"]

# (name, host) — slug auto-derived. timeout/grace are uniform.
DESIRED = [
    ("restic chat weechat",      "chat"),
    ("restic web2 gotosocial",   "web2"),
    ("restic mail stalwart",     "mail"),
    ("restic mc1 minecraft",     "mc1"),
]

TIMEOUT = 25 * 3600   # 25h after last success → "down"
GRACE   = 6  * 3600   # +6h before paging


def api(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(
        f"{API}{path}", data=data, method=method,
        headers={"X-Api-Key": KEY, "Content-Type": "application/json"},
    )
    try:
        return json.load(urllib.request.urlopen(req, timeout=15))
    except urllib.error.HTTPError as e:
        sys.exit(f"HTTP {e.code}: {e.read().decode(errors='replace')}")


def fetch():
    return {c["name"]: c for c in api("GET", "/checks/").get("checks", [])}


def main():
    apply = "--apply" in sys.argv
    existing = fetch()

    create, keep = [], []
    for name, host in DESIRED:
        if name in existing:
            keep.append((name, existing[name]))
        else:
            create.append((name, host))

    print(f"=== existing ({len(existing)}) ===")
    for n, c in existing.items():
        print(f"  - {n}  →  {c.get('ping_url', '?')}")
    print(f"\n=== keep ({len(keep)}) ===")
    for n, _ in keep: print(f"  ✓ {n}")
    print(f"\n=== create ({len(create)}) ===")
    for n, host in create:
        print(f"  + {n}  (tags: host:{host} restic)")

    if not apply:
        print("\n(dry-run — pass --apply to create)")
        return 0

    for name, host in create:
        print(f"\ncreating {name}…")
        r = api("POST", "/checks/", {
            "name": name,
            "tags": f"host:{host} restic",
            "timeout": TIMEOUT,
            "grace": GRACE,
            # `unique` lets POST act as idempotent get-or-create on name.
            "unique": ["name"],
        })
        print(f"  → {r.get('ping_url')}")

    print("\n=== ALL ping URLs (paste into agenix) ===")
    for c in fetch().values():
        print(f"  {c['name']:30}  {c['ping_url']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
