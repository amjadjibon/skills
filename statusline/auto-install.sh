#!/usr/bin/env bash
# SessionStart hook: install the dev-skills status line on first run, and keep the
# installed copy in sync with the plugin afterwards. Silent, and deliberately timid —
# it never overwrites another status line and never reinstates one you removed.
#
# State lives in two marker files next to settings.json:
#   .dev-skills.statusline-installed  we installed it (so we may refresh it)
#   .dev-skills.statusline-optout     you removed it (so we leave it alone forever)
#
# Opt out ahead of time: touch ~/.claude/.dev-skills.statusline-optout
set -euo pipefail

config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings="$config_dir/settings.json"
target="$config_dir/dev-skills.statusline.sh"
installed_marker="$config_dir/.dev-skills.statusline-installed"
optout_marker="$config_dir/.dev-skills.statusline-optout"
src="$(cd "$(dirname "$0")" && pwd)/statusline.sh"

[ -f "$optout_marker" ] && exit 0
command -v python3 >/dev/null 2>&1 || exit 0
[ -f "$src" ] || exit 0
mkdir -p "$config_dir"
[ -f "$settings" ] || printf '{}\n' > "$settings"

# ours | other | none — what settings.json currently points at
state=$(python3 - "$settings" "$target" <<'PY' 2>/dev/null || echo other
import json, sys
try:
    cmd = (json.load(open(sys.argv[1])).get("statusLine") or {}).get("command", "")
except Exception:
    print("other"); raise SystemExit
print("ours" if sys.argv[2] in cmd else ("none" if not cmd else "other"))
PY
)

case "$state" in
    other)
        # someone else's status line — never touch it
        exit 0
        ;;
    none)
        if [ -f "$installed_marker" ]; then
            # we installed it and it's gone: a deliberate removal, so stop offering
            touch "$optout_marker"
            rm -f "$installed_marker" "$target"
            exit 0
        fi
        ;;
esac

cp "$src" "$target"
chmod +x "$target"
touch "$installed_marker"

# Runs for "ours" too, not just "none": refreshInterval was added after the first
# releases, and without it the reset countdowns and elapsed time freeze at their
# last value whenever the session sits idle — updates are otherwise event-driven.
# An interval you set yourself is left alone.
python3 - "$settings" "$target" <<'PY' >/dev/null 2>&1 || true
import json, sys
p, target = sys.argv[1], sys.argv[2]
s = json.load(open(p))
sl = s.get("statusLine") or {}
sl.setdefault("refreshInterval", 10)   # seconds; minute-resolution countdowns never read stale
sl["type"], sl["command"] = "command", f'bash "{target}"'
s["statusLine"] = sl
json.dump(s, open(p, "w"), indent=2)
open(p, "a").write("\n")
PY
