#!/usr/bin/env bash
# dev-skills status line, two lines:
#   [dev-skills] <dir> (<branch>) <model> <used>/<size> (<pct>%)
#   $<cost> · <duration> · +<added>/-<removed> · 5h <used>% in <reset> · 7d <used>% in <reset>
# Claude Code passes the session JSON on stdin.
input=$(cat)

if command -v jq >/dev/null 2>&1; then
    model=$(printf '%s' "$input" | jq -r '.model.display_name // empty')
    dir=$(printf '%s' "$input" | jq -r '.workspace.current_dir // empty')
    # used_percentage counts input tokens only, so match it with the same input-only total
    ctx=$(printf '%s' "$input" | jq -r '
        .context_window
        | select(. != null and .context_window_size != null)
        | [(.total_input_tokens // 0), .context_window_size, (.used_percentage // 0)]
        | @tsv')
    cost=$(printf '%s' "$input" | jq -r '
        .cost
        | select(. != null)
        | [(.total_cost_usd // 0), (.total_duration_ms // 0),
           (.total_lines_added // 0), (.total_lines_removed // 0)]
        | @tsv')
    # rate_limits: Claude.ai subscribers only, each window independently absent
    limits=$(printf '%s' "$input" | jq -r '
        select(.rate_limits != null)
        | [(.rate_limits.five_hour.used_percentage // "" | if . == "" then "" else round end),
           (.rate_limits.five_hour.resets_at // ""),
           (.rate_limits.seven_day.used_percentage // "" | if . == "" then "" else round end),
           (.rate_limits.seven_day.resets_at // "")]
        | @tsv')
else
    model="" dir="" ctx="" cost="" limits=""
fi
[ -n "$dir" ] || dir="$PWD"

branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)

# 12345 -> 12.3k, 200000 -> 200k, 1000000 -> 1M
humanize() {
    awk -v n="$1" 'BEGIN {
        if (n >= 1000000) { m = n / 1000000; printf (m == int(m) ? "%dM" : "%.1fM"), m }
        else if (n >= 100000) printf "%dk", int(n / 1000 + 0.5)
        else if (n >= 1000) printf "%.1fk", n / 1000
        else printf "%d", n
    }'
}

# 45000 -> 45s, 754000 -> 12m, 7500000 -> 2h5m
duration() {
    awk -v ms="$1" 'BEGIN {
        s = int(ms / 1000)
        if (s >= 3600) printf "%dh%dm", int(s / 3600), int((s % 3600) / 60)
        else if (s >= 60) printf "%dm", int(s / 60)
        else printf "%ds", s
    }'
}

# epoch seconds -> how long until then: 2h5m, 45m, 3d4h. Empty once it's passed.
resets_in() {
    [ -n "${1:-}" ] || return 0
    awk -v at="$1" -v now="$(date +%s)" 'BEGIN {
        s = at - now
        if (s <= 0) exit
        if (s >= 86400) printf "%dd%dh", int(s / 86400), int((s % 86400) / 3600)
        else if (s >= 3600) printf "%dh%dm", int(s / 3600), int((s % 3600) / 60)
        else printf "%dm", int(s / 60) + 1
    }'
}

# green under half, amber past half, red past 80%
usage_color() {
    if [ "${1:-0}" -ge 80 ] 2>/dev/null; then printf '174'
    elif [ "${1:-0}" -ge 50 ] 2>/dev/null; then printf '180'
    else printf '108'
    fi
}

DIM='\033[38;5;244m'   # labels and separators
OFF='\033[0m'

# "label value" with a dim label
seg() { printf "${DIM}%s${OFF} \033[38;5;%sm%s${OFF}" "$1" "$2" "$3"; }

line1=$(printf '\033[38;5;108m[dev-skills]\033[0m \033[38;5;110m%s\033[0m' "$(basename "$dir")")
[ -n "$branch" ] && line1="$line1 $(printf '\033[38;5;180m(%s)\033[0m' "$branch")"
[ -n "$model" ] && line1="$line1 $(printf '\033[38;5;245m%s\033[0m' "$model")"

if [ -n "$ctx" ]; then
    IFS=$'\t' read -r used size pct <<< "$ctx"
    pct=${pct%%.*}
    line1="$line1 $(seg "ctx" "$(usage_color "$pct")" "$(humanize "$used")/$(humanize "$size") ${pct}%")"
fi

sep=$(printf "${DIM} · ${OFF}")
parts=""
if [ -n "$cost" ]; then
    IFS=$'\t' read -r usd ms added removed <<< "$cost"
    parts=$(seg "cost" 179 "$(printf '$%.2f' "$usd")")
    parts="$parts$sep$(seg "time" 245 "$(duration "$ms")")"
    parts="$parts$sep$(printf "${DIM}edits${OFF} \033[38;5;108m+%s${OFF}\033[38;5;174m/-%s${OFF}" "$added" "$removed")"
fi
if [ -n "$limits" ]; then
    IFS=$'\t' read -r five five_at seven seven_at <<< "$limits"
    # how much of the window is spent, and how long until it refills
    if [ -n "$five" ]; then
        parts="${parts:+$parts$sep}$(seg "used 5h" "$(usage_color "$five")" "${five}%")"
        in=$(resets_in "$five_at")
        [ -n "$in" ] && parts="$parts$(printf "${DIM} in %s${OFF}" "$in")"
    fi
    if [ -n "$seven" ]; then
        parts="${parts:+$parts$sep}$(seg "7d" "$(usage_color "$seven")" "${seven}%")"
        in=$(resets_in "$seven_at")
        [ -n "$in" ] && parts="$parts$(printf "${DIM} in %s${OFF}" "$in")"
    fi
fi

printf '%s' "$line1"
[ -n "$parts" ] && printf '\n%s' "$parts"
