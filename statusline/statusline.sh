#!/usr/bin/env bash
# dev-skills status line, two lines:
#   [dev-skills] <dir> (<branch>) wt <worktree> <model> ctx <bar> <used>/<size> <pct>% session <id>
#   $<cost> · <duration> · +<added>/-<removed> · 5h <bar> <used>% in <reset> · 7d <bar> <used>% in <reset>
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

# A meter for a percentage: 30% of 8 cells -> ##...... Sets a global rather than
# printing, because $(…) would fork once per bar.
#
# Deliberately ASCII. macOS ships bash 3.2, which corrupts multibyte string
# concatenation — building this out of ▓ and ░ there yields two stray bytes
# instead of eight block characters. ASCII also keeps one cell one byte, so the
# truncation arithmetic needs no separate uncoloured copy of the meter.
bar() {  # pct cells
    local pct=$1 cells=$2 i n=0
    [ "$pct" -gt 0 ] 2>/dev/null && n=$((pct * cells / 100))
    [ "$n" -gt "$cells" ] && n=$cells
    BAR=""
    for ((i = 0; i < cells; i++)); do
        if [ "$i" -lt "$n" ]; then BAR="$BAR#"; else BAR="$BAR."; fi
    done
}

# Claude Code exports the terminal width, and a status line that wraps looks broken.
# Each line is built left to right and a segment that would overrun is skipped, so
# the rightmost — the least load-bearing — are the ones that go. 0 means unknown:
# never truncate rather than guess.
width=${COLUMNS:-0}

# add() appends "<plain> <coloured>" to the line named by $1 unless it overruns.
# The plain copy exists only to measure: escape codes have no width but plenty
# of length, so ${#…} on the coloured string would be nonsense.
add() {  # line_var separator plain coloured
    local var=$1 gap=$2 plain=$3 colour=$4 gapc=$gap_colour cur_p cur_c full
    eval "cur_p=\$${var}_plain cur_c=\$$var full=\$${var}_full"
    [ -z "$full" ] || return 0   # once one segment overruns, stop: a prefix of the
    [ -n "$cur_p" ] || { gap="" gapc=""; }   # line beats a line with a hole in it
    if [ "$width" -gt 0 ] && [ $((${#cur_p} + ${#gap} + ${#plain})) -gt "$width" ]; then
        eval "${var}_full=1"
        return 0
    fi
    eval "${var}_plain=\$cur_p\$gap\$plain"
    eval "$var=\$cur_c\$gapc\$colour"
}

l1=$(printf '\033[38;5;%sm[dev-skills]\033[0m \033[38;5;110m%s\033[0m' "$GREEN" "${dir##*/}")
l1_plain="[dev-skills] ${dir##*/}"
gap_colour=" "
[ -n "$branch" ] && add l1 " " "($branch)" "$(printf '\033[38;5;180m(%s)\033[0m' "$branch")"
# a worktree looks exactly like the real checkout otherwise — and the agents run in them
[ -n "$worktree" ] && add l1 " " "wt $worktree" "$(seg "wt" "$YELLOW" "$worktree")"
[ -n "$model" ] && add l1 " " "$model" "$(printf '\033[38;5;245m%s\033[0m' "$model")"
if [ -n "$ctx_size" ]; then
    bar "$ctx_pct" 8
    ctx="$(humanize "$ctx_used")/$(humanize "$ctx_size") ${ctx_pct}%"
    add l1 " " "ctx $BAR $ctx" \
        "$(seg "ctx" "$(usage_color "$ctx_pct")" "$BAR $ctx")"
fi
# the transcript is ~/.claude/projects/<project>/<session>.jsonl, so print it whole
[ -n "$session" ] && add l1 " " "session $session" "$(seg "session" 245 "$session")"

l2="" l2_plain="" l2_full=""
gap_colour=$(printf "${DIM} · ${OFF}")
if [ -n "$usd" ]; then
    add l2 " - " "cost $(printf '$%.2f' "$usd")" "$(seg "cost" 179 "$(printf '$%.2f' "$usd")")"
    add l2 " - " "time $(duration "$ms")" "$(seg "time" 245 "$(duration "$ms")")"
    add l2 " - " "edits +$added/-$removed" \
        "$(printf "${DIM}edits${OFF} \033[38;5;%sm+%s${OFF}\033[38;5;%sm/-%s${OFF}" \
            "$GREEN" "$added" "$RED" "$removed")"
fi
# how much of each window is spent, and how long until it refills
for window in "used 5h|$five|$five_at" "7d|$seven|$seven_at"; do
    IFS='|' read -r label pct at <<< "$window"
    [ -n "$pct" ] || continue
    in=$(resets_in "$at")
    bar "$pct" 5
    add l2 " - " "$label $BAR ${pct}%${in:+ in $in}" \
        "$(seg "$label" "$(usage_color "$pct")" "$BAR ${pct}%")${in:+$(printf "${DIM} in %s${OFF}" "$in")}"
done

printf '%s' "$l1"
[ -n "$l2" ] && printf '\n%s' "$l2"
exit 0   # an empty line two must not look like a failed status line
