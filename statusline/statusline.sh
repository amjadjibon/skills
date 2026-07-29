#!/usr/bin/env bash
# dev-skills status line, two lines:
#   [dev-skills] <dir> (<branch>) wt <worktree> <model> ctx <used>/<size> <pct>% session <id>
#   $<cost> · <duration> · +<added>/-<removed> · 5h <used>% in <reset> · 7d <used>% in <reset>
#
# Claude Code passes the session JSON on stdin and re-renders constantly, so this
# does its whole job in three subprocesses: one jq, one git, one date. Everything
# else is bash arithmetic — no awk, no basename.
input=$(cat)

# One jq pass for every field, as a fixed 15-column row. Absent values come back
# empty so the render below can drop the segment — which rules out @tsv, because
# tab is IFS whitespace and bash would collapse the empty columns and shift every
# field left. \x1f (unit separator) is non-whitespace, so empties survive.
fields=$(printf '%s' "$input" | jq -r '
    (.context_window // {}) as $c
    | (.cost // {}) as $k
    | (.rate_limits // {}) as $r
    | [ (.model.display_name // ""),
        (.workspace.current_dir // .cwd // ""),
        (.workspace.git_worktree // ""),
        # used_percentage counts input tokens only, so pair it with the input-only total
        (if $c.context_window_size == null then "" else ($c.total_input_tokens // 0) end),
        ($c.context_window_size // ""),
        (if $c.context_window_size == null then "" else ($c.used_percentage // 0 | floor) end),
        ($k.total_cost_usd // ""),
        ($k.total_duration_ms // 0),
        ($k.total_lines_added // 0),
        ($k.total_lines_removed // 0),
        # rate_limits: Claude.ai subscribers only, each window independently absent
        ($r.five_hour.used_percentage // "" | if . == "" then "" else round end),
        ($r.five_hour.resets_at // ""),
        ($r.seven_day.used_percentage // "" | if . == "" then "" else round end),
        ($r.seven_day.resets_at // ""),
        (.session_id // "") ]
    | map(tostring) | join("\u001f")' 2>/dev/null)

IFS=$'\037' read -r model dir worktree ctx_used ctx_size ctx_pct \
    usd ms added removed five five_at seven seven_at session <<< "$fields"

[ -n "$dir" ] || dir="$PWD"
branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
now=$(date +%s)

# 12345 -> 12.3k, 200000 -> 200k, 1000000 -> 1M
humanize() {
    local n=$1 w f
    if [ "$n" -ge 1000000 ]; then
        w=$((n / 1000000)) f=$(((n % 1000000) / 100000))
        if [ "$f" -eq 0 ]; then printf '%dM' "$w"; else printf '%d.%dM' "$w" "$f"; fi
    elif [ "$n" -ge 100000 ]; then printf '%dk' $(((n + 500) / 1000))
    elif [ "$n" -ge 1000 ]; then printf '%d.%dk' $((n / 1000)) $(((n % 1000) / 100))
    else printf '%d' "$n"
    fi
}

# 45000 -> 45s, 754000 -> 12m, 7500000 -> 2h5m
duration() {
    local s=$((${1%%.*} / 1000))
    if [ "$s" -ge 3600 ]; then printf '%dh%dm' $((s / 3600)) $((s % 3600 / 60))
    elif [ "$s" -ge 60 ]; then printf '%dm' $((s / 60))
    else printf '%ds' "$s"
    fi
}

# epoch seconds -> how long until then: 2h5m, 45m, 3d4h. Empty once it's passed.
resets_in() {
    [ -n "${1:-}" ] || return 0
    local s=$((${1%%.*} - now))
    if [ "$s" -le 0 ]; then return 0
    elif [ "$s" -ge 86400 ]; then printf '%dd%dh' $((s / 86400)) $((s % 86400 / 3600))
    elif [ "$s" -ge 3600 ]; then printf '%dh%dm' $((s / 3600)) $((s % 3600 / 60))
    else printf '%dm' $((s / 60 + 1))
    fi
}

GREEN=76 YELLOW=220 RED=196   # the traffic light every percentage is scored against
DIM='\033[38;5;244m'          # labels and separators
OFF='\033[0m'

# green under 50%, yellow under 80%, red at 80% and above
usage_color() {
    if [ "${1:-0}" -ge 80 ] 2>/dev/null; then printf '%s' "$RED"
    elif [ "${1:-0}" -ge 50 ] 2>/dev/null; then printf '%s' "$YELLOW"
    else printf '%s' "$GREEN"
    fi
}

# "label value" with a dim label
seg() { printf "${DIM}%s${OFF} \033[38;5;%sm%s${OFF}" "$1" "$2" "$3"; }

line1=$(printf '\033[38;5;%sm[dev-skills]\033[0m \033[38;5;110m%s\033[0m' "$GREEN" "${dir##*/}")
[ -n "$branch" ] && line1="$line1 $(printf '\033[38;5;180m(%s)\033[0m' "$branch")"
# a worktree looks exactly like the real checkout otherwise — and the agents run in them
[ -n "$worktree" ] && line1="$line1 $(seg "wt" "$YELLOW" "$worktree")"
[ -n "$model" ] && line1="$line1 $(printf '\033[38;5;245m%s\033[0m' "$model")"
[ -n "$ctx_size" ] && line1="$line1 $(seg "ctx" "$(usage_color "$ctx_pct")" \
    "$(humanize "$ctx_used")/$(humanize "$ctx_size") ${ctx_pct}%")"
# the first block is enough to find the transcript under ~/.claude/projects/
[ -n "$session" ] && line1="$line1 $(seg "session" 245 "${session%%-*}")"

sep=$(printf "${DIM} · ${OFF}")
parts=""
if [ -n "$usd" ]; then
    parts=$(seg "cost" 179 "$(printf '$%.2f' "$usd")")
    parts="$parts$sep$(seg "time" 245 "$(duration "$ms")")"
    parts="$parts$sep$(printf "${DIM}edits${OFF} \033[38;5;%sm+%s${OFF}\033[38;5;%sm/-%s${OFF}" \
        "$GREEN" "$added" "$RED" "$removed")"
fi
# how much of each window is spent, and how long until it refills
for window in "used 5h|$five|$five_at" "7d|$seven|$seven_at"; do
    IFS='|' read -r label pct at <<< "$window"
    [ -n "$pct" ] || continue
    parts="${parts:+$parts$sep}$(seg "$label" "$(usage_color "$pct")" "${pct}%")"
    in=$(resets_in "$at")
    [ -n "$in" ] && parts="$parts$(printf "${DIM} in %s${OFF}" "$in")"
done

printf '%s' "$line1"
[ -n "$parts" ] && printf '\n%s' "$parts"
exit 0   # an empty line two must not look like a failed status line
