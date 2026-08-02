# Status Line

`statusline/statusline.sh` renders the two lines under your prompt. The [README](../README.md#status-line) covers installing and opting out; this is what each segment means and why it looks the way it does.

Regenerate the image in the README with `python3 scripts/render-statusline.py` after changing the format.

## Segments

| Segment | Field | Notes |
| ------- | ----- | ----- |
| `skills(main)` | `workspace.current_dir`, `git branch` | Directory basename and current branch — the short commit SHA instead when HEAD is detached |
| `#42 pending` | `pr.number`, `pr.review_state` | Only while an open PR exists for the branch; disappears when it merges |
| `wt phase-2-auth` | `workspace.git_worktree` | Only inside a linked worktree — the agents run in them, and nothing else on the line distinguishes one from the real checkout |
| `Opus 5 xhigh` | `model.display_name`, `effort.level` | Effort reads as part of the model phrase; absent on models without the parameter |
| `fast` | `fast_mode` | Shown only when [fast mode](https://code.claude.com/docs/en/fast-mode) is on |
| `ctx 183k/1M 18%` | `context_window` | Input tokens vs. window size — the same input-only basis Claude Code uses for `used_percentage`, so the fraction and the percentage agree |
| `statusline polish` | `session_name` | The name set with `--name` / `/rename`, or the AI-generated title. Absent until one exists |
| `45fdd1e0-af3f-…` | `session_id` | Always shown, after the name — the transcript is `~/.claude/projects/<project>/<session_id>.jsonl` |
| `usage: 5h 40% [resets in 3h53m] · 7d 20% [resets in 3d9h]` | `rate_limits` | Claude.ai Pro/Max only, after the first API response. How much of each window is spent and when it refills |
| `cost: ~$71.99` | `cost.total_cost_usd` | The `~` marks it as a client-side estimate at API rates — on a subscription nothing was billed at all. `/clear` resets it. There is no token count beside it because the payload has no cumulative one: `total_input_tokens` is what is in the window right now (already shown as `ctx`) and `total_output_tokens` is only the most recent response's output |
| `time: 13h34m[api 1h11m]` | `cost.total_duration_ms`, `total_api_duration_ms` | Elapsed wall clock, with the part spent waiting on the model bracketed beside it — tells you whether a long session was inference or reading and typing. A zero trailing component is dropped (`4h`, not `4h0m`), and the bracketed half is absent when the field is not reported |
| `edits: +1098/-259` | `cost.total_lines_added/removed` | Additions green, deletions red |

Each segment is dropped when its field is absent, so line two disappears entirely on a fresh session.

## Why it reads this way

Line two is ordered by urgency rather than convention — segments drop from the right, and on a narrow pane the window that says when you get cut off matters more than a notional cost. Both lines use the same dim `·` separator so they read as one block.

Line two names each group — `usage:`, `cost:`, `time:`, `edits:` — and a figure that qualifies another sits in brackets beside it rather than taking a segment of its own: `40% [resets in 3h53m]`, `13h34m[api 1h11m]`. `usage:` heads the rate-limit group and attaches to whichever window renders first, so it still reads correctly when the 5-hour window is absent. Line one stays unlabelled where a value announces itself — a `#number`, a branch in parentheses, a UUID — and keeps `ctx` and `wt`, which do not.

Colour always means "this is a value" — labels and separators stay grey. Values are coloured by kind: blue for the directory, gold for the branch and PR, `146` for session state you did not measure (model, effort), yellow for a non-default mode (`wt`, `fast`), tan for the cost estimate, mauve for the session id — an identifier you copy rather than read. The percentages share one traffic light: green under 50%, yellow under 80%, red at 80% and above, in muted hues rather than full-intensity ones, since the line sits in peripheral vision all day and saturated green/red read as alarms.

Claude Code exports the terminal width, and a wrapped status line looks broken, so each line is built left to right and stops at the first segment that would overrun — you always get a prefix, never a hole. Narrow it far enough and the session id goes, then `ctx`, then the rate-limit windows, down to `[dev-skills] skills` alone. Segments are measured on an uncoloured copy of the text, since escape codes have length but no width.

## Refresh

The `SessionStart` hook sets `refreshInterval: 10` on the `statusLine` entry. Updates are otherwise event-driven — prompt submitted, response finished, tool used — so an idle session leaves the reset countdowns and the elapsed time frozen at whatever they were on your last turn. An interval you set yourself is left alone.

## Tests

`statusline/tests/` holds fixture pairs — `<case>.json` in, `<case>.expected` out with the escape codes stripped. `python3 scripts/validate.py` renders each one and diffs it, under `/bin/bash` specifically, because macOS ships bash 3.2 and the bugs that only appear there are the ones that reach users. Because the goldens strip ANSI before diffing, the colour thresholds get their own check either side of 50% and 80% — otherwise swapping two colour constants would leave every fixture passing. `STATUSLINE_NOW` pins the clock so the reset countdowns are reproducible, and an optional `# COLUMNS=<n>` header line on the expected file sets the terminal width for that case.

`validate.py` also exercises both installers against sandboxed `CLAUDE_CONFIG_DIR`s — one case per guarantee (foreign `statusLine` untouched, deletion honoured as a permanent opt-out, a `refreshInterval` you chose preserved), plus the fresh install, the migration, and `install.sh --uninstall`.

## Implementation notes

The status line re-renders constantly, so it keeps to three subprocesses: one `jq` for every payload field at once, one `git` for the branch, one `date` for the reset countdowns. Formatting is bash arithmetic. The `jq` output is joined on `\x1f` rather than `@tsv`, because tab is IFS whitespace and bash would collapse the empty columns and shift every field left.

The scripts honour `CLAUDE_CONFIG_DIR`, need `python3` to edit settings safely, and need `jq` for everything but the badge, directory, and branch. Context numbers are absent until the first API response of a session, and again after `/compact`; `rate_limits` is Claude.ai subscriber-only. For a single-line status line, delete the trailing `printf '\n…'` from the script.
