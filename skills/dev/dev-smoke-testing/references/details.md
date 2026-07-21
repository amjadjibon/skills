# Smoke Testing Templates

Worked examples for `dev-smoke-testing`. Adapt endpoints/checks, don't paste unmodified.

## `scripts/test-create-user.sh` (Bash)

```bash
#!/usr/bin/env bash
set -euo pipefail
BASE_URL="${1:?usage: $0 <base-url>}"

status=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
  -X POST "$BASE_URL/api/v1/users" \
  -d '{"email": "smoke-test@example.com"}')

[[ "$status" == "201" ]] || { echo "FAIL: create-user — got $status"; exit 1; }
echo "OK: create-user"
```

One check, one file, named for what it checks — not a shared "smoke-test.sh" grab-bag. Run several of these directly (`for f in scripts/test-*.sh; do bash "$f" "$BASE_URL" || FAILED=1; done`) when more than one check is needed; don't merge them into one script.

## `scripts/test-get-user-session.py` (Python, when bash can't do it cleanly)

```python
#!/usr/bin/env python3
import sys, requests

base_url = sys.argv[1] if len(sys.argv) > 1 else sys.exit("usage: test-get-user-session.py <base-url>")

resp = requests.get(f"{base_url}/api/v1/session", timeout=5)
if resp.status_code != 200:
    sys.exit(f"FAIL: get-user-session — expected 200, got {resp.status_code}")

body = resp.json()
assert body.get("status") == "active", f"FAIL: session body — got {body}"
print("OK: get-user-session")
```

Reach for Python only when the check needs something bash+curl makes awkward — here, asserting on a JSON response body.
