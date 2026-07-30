#!/usr/bin/env bash
# dev-skills status line, two lines:
#   [dev-skills] <dir>(<branch>) · #<pr> · wt <wt> · <model> <effort> · ctx <used>/<size> <pct>% · <session>
#   5h <pct>% in <reset> · 7d <pct>% in <reset> · ~$<cost> · tok <in>/<out> · cache <read>/<write> · <duration> · +<added>/-<removed>
#
# Labels only survive where the value alone is ambiguous: ctx and tok keep
# theirs, a currency symbol and a +n/-n pair do not need one.
#
# Claude Code passes the session JSON on stdin and re-renders constantly, so this
# does its whole job in three subprocesses: one jq, one git, one date. Everything
# else is bash arithmetic — no awk, no basename.
input=$(cat)

# One jq pass for every field, as a fixed 20-column row. Absent values come back
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
        (.session_id // ""),
        # both change mid-session via /effort and /fast, and nothing else shows it
        (.effort.level // ""),
        (if .fast_mode == true then "fast" else "" end),
        # present only while an open PR exists for the branch; review_state may be absent
        (.pr.number // ""),
        (.pr.review_state // ""),
        (.transcript_path // "") ]
    | map(tostring) | join("\u001f")' 2>/dev/null)

IFS=$'\037' read -r model dir worktree ctx_used ctx_size ctx_pct \
    usd ms added removed five five_at seven seven_at session effort fast \
    pr pr_state transcript <<< "$fields"

# Session token totals, summed from the transcript the payload points at — the
# payload itself only ever describes the current context window.
#
# Keyed by message.id, NOT summed per line: the transcript writes the same
# assistant message up to three times, each copy carrying an identical usage
# block, so adding up lines overstates every figure by roughly 2x. Messages
# without an id fall back to their line index so they are never collapsed.
#
# These approximate /usage rather than matching it: /usage reads a ledger this
# file is only a partial view of (it has no record of the haiku calls at all).
tokens=""
[ -r "$transcript" ] && tokens=$(jq -rs '
    reduce (to_entries[] | select(.value.message.usage != null)) as $e ({};
      .[($e.value.message.id // ($e.key | tostring))] = $e.value.message.usage)
    | [.[]] as $u
    | [ ($u | map(.input_tokens // 0) | add // 0),
        ($u | map(.output_tokens // 0) | add // 0),
        ($u | map(.cache_read_input_tokens // 0) | add // 0),
        ($u | map(.cache_creation_input_tokens // 0) | add // 0) ]
    | map(tostring) | join("\u001f")' "$transcript" 2>/dev/null)
IFS=$'\037' read -r tok_in tok_out cache_in cache_out <<< "$tokens"

[ -n "$dir" ] || dir="$PWD"
branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
# detached HEAD reports the literal "HEAD", which says nothing at exactly the
# moment you most need to know where you are — show the commit instead
[ "$branch" = HEAD ] && branch=$(git -C "$dir" rev-parse --short HEAD 2>/dev/null)
# STATUSLINE_NOW pins the clock so the reset countdowns are reproducible under test
now=${STATUSLINE_NOW:-$(date +%s)}

# 12345 -> 12.3k, 200000 -> 200k, 1000000 -> 1M
# Every branch rounds to the nearest tenth rather than truncating, so 1999 reads
# 2.0k and not 1.9k. `t` is the value in tenths of the unit being printed.
humanize() {
    local n=$1 t
    if [ "$n" -ge 1000000 ]; then
        t=$(((n + 50000) / 100000))
        if [ $((t % 10)) -eq 0 ]; then printf '%dM' $((t / 10)); else printf '%d.%dM' $((t / 10)) $((t % 10)); fi
    elif [ "$n" -ge 100000 ]; then printf '%dk' $(((n + 500) / 1000))
    elif [ "$n" -ge 1000 ]; then
        t=$(((n + 50) / 100))
        if [ "$t" -ge 1000 ]; then printf '%dk' $((t / 10)); else printf '%d.%dk' $((t / 10)) $((t % 10)); fi
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
# Every branch rounds down, so the countdown only ever decreases; rounding the
# minutes up while the hours rounded down made it jump backwards across redraws.
resets_in() {
    [ -n "${1:-}" ] || return 0
    local s=$((${1%%.*} - now))
    if [ "$s" -le 0 ]; then return 0
    elif [ "$s" -ge 86400 ]; then printf '%dd%dh' $((s / 86400)) $((s % 86400 / 3600))
    elif [ "$s" -ge 3600 ]; then printf '%dh%dm' $((s / 3600)) $((s % 3600 / 60))
    elif [ "$s" -ge 60 ]; then printf '%dm' $((s / 60))
    else printf '<1m'
    fi
}

# The traffic light every percentage is scored against. Muted on purpose: these
# sit in peripheral vision all day, so they are picked for distinct hue rather
# than saturation — full-intensity 76/220/196 read as alarms after an hour.
GREEN=71 YELLOW=179 RED=167
MAUVE=140                     # identifiers you copy rather than read: the session id
TAN=137                       # cost, kept off the traffic light so it never reads as a warning
STATE=146                     # session state you did not measure: model, effort
TIME=144                      # elapsed time
BLUE=110                      # where you are: the directory
GOLD=180                      # which branch you are on
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

# Both lines use the same dim separator, so they read as one block rather than
# two formats stacked. The plain copy stays ASCII — it is only ever measured.
sep_plain=" - "
gap_colour=$(printf "${DIM} · ${OFF}")

# The branch belongs to the directory, so it hangs off it rather than standing
# as its own segment — skills(main), not skills · main.
l1=$(printf '\033[38;5;%sm[dev-skills]\033[0m \033[38;5;%sm%s\033[0m' "$GREEN" "$BLUE" "${dir##*/}")
l1_plain="[dev-skills] ${dir##*/}"
if [ -n "$branch" ]; then
    l1="$l1$(printf '\033[38;5;%sm(%s)\033[0m' "$GOLD" "$branch")"
    l1_plain="$l1_plain($branch)"
fi
# an open PR for this branch, and where its review stands
[ -n "$pr" ] && add l1 "$sep_plain" "#$pr${pr_state:+ $pr_state}" \
    "$(printf '\033[38;5;%sm#%s\033[0m' "$GOLD" "$pr")${pr_state:+$(printf "${DIM} %s${OFF}" "$pr_state")}"
# a worktree looks exactly like the real checkout otherwise — and the agents run in them
[ -n "$worktree" ] && add l1 "$sep_plain" "wt $worktree" "$(seg "wt" "$YELLOW" "$worktree")"
# effort qualifies the model, so it reads as one phrase rather than its own segment
[ -n "$model" ] && add l1 "$sep_plain" "$model${effort:+ $effort}" \
    "$(printf '\033[38;5;%sm%s\033[0m' "$STATE" "$model${effort:+ $effort}")"
[ -n "$fast" ] && add l1 "$sep_plain" "$fast" "$(printf '\033[38;5;%sm%s\033[0m' "$YELLOW" "$fast")"
if [ -n "$ctx_size" ]; then
    ctx="$(humanize "$ctx_used")/$(humanize "$ctx_size") ${ctx_pct}%"
    add l1 "$sep_plain" "ctx $ctx" "$(seg "ctx" "$(usage_color "$ctx_pct")" "$ctx")"
fi
# the transcript is ~/.claude/projects/<project>/<session>.jsonl, so print it whole
[ -n "$session" ] && add l1 "$sep_plain" "$session" "$(printf '\033[38;5;%sm%s\033[0m' "$MAUVE" "$session")"

# Line two is ordered by urgency, not by convention, because add() drops from the
# right: on a narrow pane you would rather lose what a notional session cost than
# the window that says when you get cut off.
l2="" l2_plain="" l2_full=""
# how much of each window is spent, and how long until it refills
for window in "5h|$five|$five_at" "7d|$seven|$seven_at"; do
    IFS='|' read -r label pct at <<< "$window"
    [ -n "$pct" ] || continue
    in=$(resets_in "$at")
    add l2 "$sep_plain" "$label ${pct}%${in:+ in $in}" \
        "$(seg "$label" "$(usage_color "$pct")" "${pct}%")${in:+$(printf "${DIM} in %s${OFF}" "$in")}"
done
# "est", not "cost": it is a client-side estimate at API rates, and on a
# subscription nothing was billed at all
[ -n "$usd" ] && add l2 "$sep_plain" "$(printf '~$%.2f' "$usd")" \
    "$(printf '\033[38;5;%sm~$%.2f\033[0m' "$TAN" "$usd")"
# session tokens: fresh in/out, then the cached halves — read from cache, written to it
if [ -n "$tok_out" ]; then
    add l2 "$sep_plain" "tok $(humanize "$tok_in")/$(humanize "$tok_out")" \
        "$(seg "tok" "$TIME" "$(humanize "$tok_in")/$(humanize "$tok_out")")"
    add l2 "$sep_plain" "cache $(humanize "$cache_in")/$(humanize "$cache_out")" \
        "$(seg "cache" "$TIME" "$(humanize "$cache_in")/$(humanize "$cache_out")")"
fi
if [ -n "$usd" ]; then
    add l2 "$sep_plain" "$(duration "$ms")" \
        "$(printf '\033[38;5;%sm%s\033[0m' "$TIME" "$(duration "$ms")")"
    add l2 "$sep_plain" "+$added/-$removed" \
        "$(printf "\033[38;5;%sm+%s${OFF}\033[38;5;%sm/-%s${OFF}" "$GREEN" "$added" "$RED" "$removed")"
fi

printf '%s' "$l1"
[ -n "$l2" ] && printf '\n%s' "$l2"
exit 0   # an empty line two must not look like a failed status line
