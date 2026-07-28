#!/usr/bin/env bash
# Install the dev-skills status line: copy the script into the Claude config dir
# and point settings.json at the copy. Idempotent; safe to re-run after upgrades.
#
#   bash statusline/install.sh            # install
#   bash statusline/install.sh --uninstall  # remove the statusLine entry again
set -euo pipefail

config_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
settings="$config_dir/settings.json"
target="$config_dir/dev-skills.statusline.sh"
installed_marker="$config_dir/.dev-skills.statusline-installed"
optout_marker="$config_dir/.dev-skills.statusline-optout"
src="$(cd "$(dirname "$0")" && pwd)/statusline.sh"

mkdir -p "$config_dir"
[ -f "$settings" ] || printf '{}\n' > "$settings"

if [ "${1:-}" = "--uninstall" ]; then
    python3 - "$settings" <<'PY'
import json, sys
p = sys.argv[1]
s = json.load(open(p))
s.pop("statusLine", None)
json.dump(s, open(p, "w"), indent=2)
open(p, "a").write("\n")
print("removed statusLine from", p)
PY
    rm -f "$target" "$installed_marker"
    touch "$optout_marker"  # stops the SessionStart hook putting it back
    echo "opted out — delete $optout_marker to allow reinstall"
    exit 0
fi

rm -f "$optout_marker"
cp "$src" "$target"
chmod +x "$target"
touch "$installed_marker"

python3 - "$settings" "$target" <<'PY'
import json, sys
p, target = sys.argv[1], sys.argv[2]
s = json.load(open(p))
s["statusLine"] = {"type": "command", "command": f'bash "{target}"'}
json.dump(s, open(p, "w"), indent=2)
open(p, "a").write("\n")
print("statusLine ->", target, "in", p)
PY
