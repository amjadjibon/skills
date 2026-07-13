#!/usr/bin/env python3
"""Validate skill files: frontmatter, fence nesting, cross-references, doc coverage, shared conventions.

Run from the repo root: python3 scripts/validate.py
Exits non-zero on any finding.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKILLS = ROOT / "skills" / "dev"
AGENTS = ROOT / "agents"
COMMANDS = ROOT / "commands"

HYGIENE_LINE = (
    "Commit hygiene: `git add -u` for tracked files, explicit paths for new files, "
    "never `git add -A`. No `Co-authored-by:` trailers. Subject ≤72 chars, imperative, why-focused."
)
MODE_LINE = (
    "Mode is the trailing argument when it is exactly `lite`, `full`, or `ultra`; "
    "everything else is the task/feature description. No mode given → `lite`."
)
NOT_SKILLS = {"dev-skills"}  # plugin name, not a skill

errors = []


def err(path, msg):
    errors.append(f"{path.relative_to(ROOT)}: {msg}")


def check_fences(path, text):
    """CommonMark-style: a fence closes only on >= same-length fence with no info string.
    Flag an info-string fence opened inside an open block (intended nesting, same length) and unclosed blocks."""
    open_len = 0
    for i, line in enumerate(text.splitlines(), 1):
        m = re.match(r"^(`{3,})(.*)$", line.strip())
        if not m:
            continue
        ticks, info = len(m.group(1)), m.group(2).strip()
        if open_len == 0:
            open_len = ticks
        elif ticks >= open_len and not info:
            open_len = 0
        elif ticks >= open_len and info:  # same/longer fence with info string inside an open block — broken nesting
            err(path, f"line {i}: fence ```{info} opens inside an open {open_len}-backtick block — outer fence needs more backticks")
        # ticks < open_len: literal content inside the block — valid nesting
    if open_len:
        err(path, "unclosed code fence at EOF")


def check_frontmatter(path, text, dirname):
    m = re.match(r"^---\n(.*?)\n---\n", text, re.DOTALL)
    if not m:
        err(path, "missing YAML frontmatter")
        return
    fm = m.group(1)
    name = re.search(r"^name:\s*(\S+)", fm, re.MULTILINE)
    if not name:
        err(path, "frontmatter missing `name`")
    elif name.group(1) != dirname:
        err(path, f"frontmatter name `{name.group(1)}` != directory `{dirname}`")
    if not re.search(r"^description:\s*\S", fm, re.MULTILINE):
        err(path, "frontmatter missing `description`")


def main():
    skill_dirs = sorted(d.name for d in SKILLS.iterdir() if d.is_dir())
    agent_files = sorted(AGENTS.glob("*.md")) if AGENTS.is_dir() else []
    agent_names = {p.stem for p in agent_files}
    command_files = sorted(COMMANDS.glob("*.md")) if COMMANDS.is_dir() else []
    md_files = [SKILLS / d / "SKILL.md" for d in skill_dirs] + agent_files + command_files + [ROOT / "CLAUDE.md", ROOT / "README.md"]

    for path in md_files:
        if not path.exists():
            err(path, "file missing")
            continue
        text = path.read_text()
        check_fences(path, text)

        if path.name == "SKILL.md":
            check_frontmatter(path, text, path.parent.name)
        elif path.parent == AGENTS:
            check_frontmatter(path, text, path.stem)
            if "## Delivery Mode" in text and MODE_LINE not in text:
                err(path, "Delivery Mode section missing the canonical mode-parsing line")
            if "git commit -m" in text and HYGIENE_LINE not in text:
                err(path, "commits but missing the canonical commit-hygiene line")

        # every dev-* reference must be a real skill or agent
        for ref in set(re.findall(r"\bdev-[a-z][a-z-]*[a-z]\b", text)) - NOT_SKILLS - agent_names:
            if ref not in skill_dirs:
                err(path, f"references `{ref}` but skills/{ref}/ and agents/{ref}.md do not exist")

    # CLAUDE.md and README.md must list every skill and mention every agent
    for doc in ("CLAUDE.md", "README.md"):
        text = (ROOT / doc).read_text()
        for d in skill_dirs:
            if not re.search(rf"\*\*{d}\*\*|\[{d}\]", text):
                err(ROOT / doc, f"does not list skill `{d}`")
        for a in sorted(agent_names):
            if a not in text:
                err(ROOT / doc, f"does not mention agent `{a}`")

    # plugin.json and marketplace.json must exist, parse, and agree on the description
    plugin_path = ROOT / ".claude-plugin" / "plugin.json"
    market_path = ROOT / ".claude-plugin" / "marketplace.json"
    try:
        plugin = json.loads(plugin_path.read_text())
        market = json.loads(market_path.read_text())
        if plugin.get("description") != market["plugins"][0].get("description"):
            err(market_path, "plugin description out of sync with plugin.json")
    except (OSError, json.JSONDecodeError, KeyError, IndexError) as e:
        err(plugin_path, f"manifest problem: {e}")

    if errors:
        print("\n".join(errors))
        print(f"\n{len(errors)} finding(s)")
        sys.exit(1)
    print(f"OK — {len(skill_dirs)} skills validated")


if __name__ == "__main__":
    main()
