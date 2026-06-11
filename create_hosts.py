#!/usr/bin/env python3
"""
Bulk-create hosts in an AAP inventory using the bulk host_create API.
Supports AAP 2.4 (/api/v2) and AAP 2.6 (/api/controller/v2).

The bulk endpoint creates all hosts in a single DB transaction per batch,
far faster than one POST per host.

Usage:
  export CONTROLLER_HOST=https://aap.example.com
  export CONTROLLER_TOKEN=<your API token>
  export INVENTORY_ID=<numeric inventory ID>

  python3 create_hosts.py [options]

Options:
  --count          Number of hosts to create (default: 500)
  --prefix         Hostname prefix (default: host-)
                   Hosts are named host-001, host-002, ...
  --group          Create this group and add all hosts to it
  --batch-size     Hosts per bulk request (default: 100, must be <= BULK_HOST_MAX_CREATE)
  --aap-version    Force AAP version: 24 or 26 (default: auto-detect)
  --no-ssl-verify  Disable SSL certificate verification
  --dry-run        Print payload without making API calls
"""

import argparse
import json
import math
import os
import ssl
import sys
import time
import urllib.error
import urllib.request


# ---------------------------------------------------------------------------
# Env helpers
# ---------------------------------------------------------------------------

def get_env(key: str) -> str:
    val = os.environ.get(key, "").strip()
    if not val:
        print(f"ERROR: {key} is not set.", file=sys.stderr)
        sys.exit(1)
    return val


# ---------------------------------------------------------------------------
# API client
# ---------------------------------------------------------------------------

API_PATHS = {
    "24": "/api/v2",
    "26": "/api/controller/v2",
}


class ControllerAPI:
    def __init__(self, host: str, token: str, verify_ssl: bool = True, aap_version: str = "auto"):
        self.base       = host.rstrip("/")
        self.token      = token
        self.verify_ssl = verify_ssl
        self.api_base   = self._detect(aap_version)

    # ------------------------------------------------------------------
    def _ssl_ctx(self) -> ssl.SSLContext:
        ctx = ssl.create_default_context()
        if not self.verify_ssl:
            ctx.check_hostname = False
            ctx.verify_mode    = ssl.CERT_NONE
        return ctx

    def _detect(self, aap_version: str) -> str:
        if aap_version in ("24", "26"):
            path = API_PATHS[aap_version]
            print(f"AAP version forced to {aap_version} — using {path}")
            return path

        for ver, path in [("26", API_PATHS["26"]), ("24", API_PATHS["24"])]:
            url = f"{self.base}{path}/ping/"
            req = urllib.request.Request(url, headers={"Authorization": f"Bearer {self.token}"})
            try:
                with urllib.request.urlopen(req, context=self._ssl_ctx()) as r:
                    if r.status == 200:
                        print(f"Auto-detected AAP {ver} ({path})")
                        return path
            except urllib.error.HTTPError as e:
                if e.code in (401, 403):
                    print(f"Auto-detected AAP {ver} ({path})")
                    return path
            except Exception:
                pass

        print("WARNING: Could not auto-detect AAP version; defaulting to 2.4 (/api/v2)")
        return API_PATHS["24"]

    # ------------------------------------------------------------------
    def _request(self, method: str, path: str, data: dict = None) -> dict:
        url  = path if path.startswith("http") else f"{self.base}{self.api_base}{path}"
        body = json.dumps(data).encode() if data is not None else None
        req  = urllib.request.Request(
            url, data=body, method=method,
            headers={
                "Authorization": f"Bearer {self.token}",
                "Content-Type":  "application/json",
            },
        )
        try:
            with urllib.request.urlopen(req, context=self._ssl_ctx()) as r:
                return json.loads(r.read())
        except urllib.error.HTTPError as e:
            body = e.read().decode(errors="replace")
            raise RuntimeError(f"HTTP {e.code} {method} {url}: {body}") from e

    def get(self, path: str)              -> dict: return self._request("GET",  path)
    def post(self, path: str, data: dict) -> dict: return self._request("POST", path, data)


# ---------------------------------------------------------------------------
# Bulk host creation
# ---------------------------------------------------------------------------

def bulk_create_hosts(
    api:          ControllerAPI,
    inventory_id: int,
    hostnames:    list[str],
    batch_size:   int,
) -> tuple[int, int, list[str]]:
    """
    POST to /bulk/host_create/ in batches.
    Returns (created_count, skipped_count, errors).

    Payload schema:
      {
        "inventory": <id>,
        "hosts": [
          {"name": "host-001", "enabled": true},
          ...
        ]
      }

    Response:
      {"hosts_unable_to_create": [...], "total_hosts_created": N}
    """
    total      = len(hostnames)
    batches    = math.ceil(total / batch_size)
    created    = 0
    skipped    = 0
    errors     = []

    for i in range(batches):
        chunk  = hostnames[i * batch_size : (i + 1) * batch_size]
        start  = i * batch_size + 1
        end    = start + len(chunk) - 1
        print(f"  Batch {i + 1}/{batches}: hosts {start}–{end} ({len(chunk)} hosts)", flush=True)

        payload = {
            "inventory": inventory_id,
            "hosts": [{"name": h, "enabled": True} for h in chunk],
        }

        try:
            resp = api.post("/bulk/host_create/", payload)
        except RuntimeError as e:
            errors.append(f"Batch {i + 1} failed: {e}")
            continue

        batch_created = resp.get("total_hosts_created", 0)
        unable        = resp.get("hosts_unable_to_create", [])

        created += batch_created
        skipped += len(unable)

        if unable:
            for entry in unable:
                name = entry.get("name", "?")
                reason = entry.get("error", "unknown reason")
                errors.append(f"  Could not create '{name}': {reason}")

    return created, skipped, errors


# ---------------------------------------------------------------------------
# Group helpers
# ---------------------------------------------------------------------------

def ensure_group(api: ControllerAPI, inventory_id: int, group_name: str) -> int:
    try:
        grp = api.post("/groups/", {"name": group_name, "inventory": inventory_id})
        gid = grp["id"]
        print(f"Created group '{group_name}' (id={gid})")
        return gid
    except RuntimeError as e:
        if "already exists" in str(e) or "unique" in str(e).lower():
            result = api.get(f"/groups/?inventory={inventory_id}&name={group_name}")
            gid    = result["results"][0]["id"]
            print(f"Group '{group_name}' already exists (id={gid})")
            return gid
        raise


def add_hosts_to_group(api: ControllerAPI, group_id: int, inventory_id: int, host_name_set: set[str]) -> None:
    """Page through inventory hosts and bulk-add matching ones to the group."""
    print("Fetching host IDs for group assignment...")
    host_ids  = []
    next_url  = f"/hosts/?inventory={inventory_id}&page_size=200"

    while next_url:
        page = api.get(next_url)
        for h in page["results"]:
            if h["name"] in host_name_set:
                host_ids.append(h["id"])
        next_url = page.get("next")

    print(f"Adding {len(host_ids)} hosts to group (id={group_id})...")
    # The groups/<id>/hosts/ endpoint accepts a list of {id: N} objects
    for i in range(0, len(host_ids), 200):
        chunk = host_ids[i : i + 200]
        for hid in chunk:
            try:
                api.post(f"/groups/{group_id}/hosts/", {"id": hid})
            except RuntimeError as e:
                if "already" not in str(e):
                    print(f"  WARNING: could not add host id {hid} to group: {e}", file=sys.stderr)
        print(f"  {min(i + 200, len(host_ids))}/{len(host_ids)} hosts added", flush=True)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description="Bulk-create hosts in AAP 2.4 / 2.6")
    parser.add_argument("--count",         type=int, default=500,  help="Number of hosts (default: 500)")
    parser.add_argument("--prefix",        default="host-",        help="Hostname prefix (default: host-)")
    parser.add_argument("--group",         default="",             help="Group to create and assign all hosts to")
    parser.add_argument("--batch-size",    type=int, default=100,  help="Hosts per bulk request (default: 100, must be <= BULK_HOST_MAX_CREATE)")
    parser.add_argument("--aap-version",   choices=["24", "26"],   help="Force AAP version (default: auto-detect)")
    parser.add_argument("--no-ssl-verify", action="store_true",    help="Disable SSL verification")
    parser.add_argument("--dry-run",       action="store_true",    help="Print payload without creating hosts")
    args = parser.parse_args()

    controller_host  = get_env("CONTROLLER_HOST")
    controller_token = get_env("CONTROLLER_TOKEN")
    inventory_id     = int(get_env("INVENTORY_ID"))

    api = ControllerAPI(
        controller_host, controller_token,
        verify_ssl=not args.no_ssl_verify,
        aap_version=args.aap_version or "auto",
    )

    pad       = len(str(args.count))
    hostnames = [f"{args.prefix}{str(i).zfill(pad)}" for i in range(1, args.count + 1)]

    # Dry run
    if args.dry_run:
        batches = math.ceil(args.count / args.batch_size)
        print(f"DRY RUN — {args.count} hosts, {batches} batch(es) of up to {args.batch_size}")
        print(f"Inventory id : {inventory_id}")
        print(f"First host   : {hostnames[0]}")
        print(f"Last host    : {hostnames[-1]}")
        print(f"\nExample batch payload:")
        sample = hostnames[:3]
        print(json.dumps({
            "inventory": inventory_id,
            "hosts": [{"name": h, "enabled": True} for h in sample] + [{"name": "..."}],
        }, indent=2))
        sys.exit(0)

    # Verify inventory
    try:
        inv = api.get(f"/inventories/{inventory_id}/")
        print(f"Target inventory : [{inventory_id}] {inv['name']}")
    except RuntimeError as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)

    # Create hosts via bulk API
    print(f"\nCreating {args.count} hosts in batches of {args.batch_size}...")
    t0 = time.time()

    created, skipped, errors = bulk_create_hosts(api, inventory_id, hostnames, args.batch_size)

    elapsed = time.time() - t0
    print(f"\nDone in {elapsed:.1f}s — created: {created}, skipped/failed: {skipped}")

    if errors:
        print(f"\n{len(errors)} issue(s):")
        for e in errors[:20]:
            print(e)
        if len(errors) > 20:
            print(f"  ... and {len(errors) - 20} more")

    # Assign to group
    if args.group:
        group_id = ensure_group(api, inventory_id, args.group)
        add_hosts_to_group(api, group_id, inventory_id, set(hostnames))

    print("\nDone.")


if __name__ == "__main__":
    main()
