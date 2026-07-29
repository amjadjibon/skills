#!/usr/bin/env python3
"""Validate skill files: frontmatter, fence nesting, cross-references, doc coverage, shared conventions.

Run from the repo root: python3 scripts/validate.py
Exits non-zero on any finding.
"""
import json
import os
import re
import subprocess
import tempfile
import sys
from itertools import zip_longest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKILLS = ROOT / "skills" / "dev"
MISC_SKILLS = ROOT / "skills" / "misc"
AGENTS = ROOT / ".agents"
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


ANSI = re.compile(r"\x1b\[[0-9;]*m")


def check_statusline():
    """Render each tests/*.json fixture and diff it against its .expected file.

    Run under /bin/bash on purpose: macOS ships bash 3.2, and bugs that only
    appear there (multibyte concatenation, in particular) are exactly the ones
    that reach users. STATUSLINE_NOW pins the clock so reset countdowns are
    reproducible; COLUMNS comes from an optional `# COLUMNS=<n>` header line.
    """
    script = ROOT / "statusline" / "statusline.sh"
    tests = ROOT / "statusline" / "tests"
    if not script.exists() or not tests.is_dir():
        return
    fixtures = sorted(tests.glob("*.json"))
    if not fixtures:
        err(tests, "no fixtures — statusline.sh would go untested")
        return

    for fixture in fixtures:
        expected_path = fixture.with_suffix(".expected")
        if not expected_path.exists():
            err(fixture, f"no {expected_path.name} beside it")
            continue
        expected = expected_path.read_text().rstrip("\n").split("\n")
        env = {"PATH": os.environ.get("PATH", ""), "STATUSLINE_NOW": "1800000000", "COLUMNS": "0"}
        if expected and expected[0].startswith("# COLUMNS="):
            env["COLUMNS"] = expected.pop(0).split("=", 1)[1]
        try:
            out = subprocess.run(
                ["/bin/bash", str(script)],
                input=fixture.read_bytes(), env=env, capture_output=True, timeout=15,
            )
        except (OSError, subprocess.SubprocessError) as e:
            err(fixture, f"could not run statusline.sh: {e}")
            continue
        if out.returncode != 0:
            err(fixture, f"statusline.sh exited {out.returncode}: {out.stderr.decode(errors='replace').strip()}")
            continue
        actual = ANSI.sub("", out.stdout.decode()).rstrip("\n").split("\n")
        for i, (want, got) in enumerate(zip_longest(expected, actual, fillvalue=""), 1):
            if want != got:
                err(fixture, f"line {i} differs\n    expected: {want}\n    actual:   {got}")

    # A detached HEAD cannot be a fixture — it needs a real repo — but `rev-parse
    # --abbrev-ref` answers the literal "HEAD" there, which is exactly the state
    # where you most need to know which commit you are on.
    with tempfile.TemporaryDirectory() as tmp:
        git = ["git", "-C", tmp, "-c", "user.email=t@t", "-c", "user.name=t", "-c", "commit.gpgsign=false"]
        try:
            subprocess.run(git + ["init", "-q"], check=True, capture_output=True)
            subprocess.run(git + ["commit", "-q", "--allow-empty", "-m", "x"], check=True, capture_output=True)
            sha = subprocess.run(git + ["rev-parse", "--short", "HEAD"], check=True,
                                 capture_output=True, text=True).stdout.strip()
            subprocess.run(git + ["checkout", "-q", "--detach", sha], check=True, capture_output=True)
        except (OSError, subprocess.CalledProcessError) as e:
            err(script, f"could not build the detached-HEAD repo: {e}")
        else:
            out = subprocess.run(
                ["/bin/bash", str(script)],
                input=json.dumps({"workspace": {"current_dir": tmp}}).encode(),
                env={"PATH": os.environ.get("PATH", ""), "COLUMNS": "0"},
                capture_output=True, timeout=15,
            )
            line = ANSI.sub("", out.stdout.decode()).split("\n")[0]
            if f"({sha})" not in line:
                err(script, f"detached HEAD should render ({sha}), got: {line}")

    # {} has no current_dir, so it falls back to $PWD and cannot be a golden test —
    # but it must still render one line and exit clean rather than blowing up.
    out = subprocess.run(
        ["/bin/bash", str(script)], input=b"{}",
        env={"PATH": os.environ.get("PATH", ""), "COLUMNS": "0"},
        capture_output=True, timeout=15,
    )
    if out.returncode != 0 or not out.stdout.strip():
        err(script, f"empty input: exited {out.returncode} with {out.stdout!r}")


def main():
    skill_dirs = sorted(d.name for d in SKILLS.iterdir() if d.is_dir())
    misc_dirs = sorted(d.name for d in MISC_SKILLS.iterdir() if d.is_dir()) if MISC_SKILLS.is_dir() else []
    all_skills = skill_dirs + misc_dirs
    agent_files = sorted(AGENTS.glob("*.md")) if AGENTS.is_dir() else []
    agent_names = {p.stem for p in agent_files}
    command_files = sorted(COMMANDS.glob("*.md")) if COMMANDS.is_dir() else []
    skill_files = [SKILLS / d / "SKILL.md" for d in skill_dirs] + [MISC_SKILLS / d / "SKILL.md" for d in misc_dirs]
    # multi-file skills (e.g. prototype's LOGIC.md/UI.md) get their fences and refs checked too
    companions = sorted(p for f in skill_files for p in f.parent.glob("*.md") if p.name != "SKILL.md")
    md_files = skill_files + companions + agent_files + command_files + [ROOT / "CLAUDE.md", ROOT / "README.md"]

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
                err(path, f"references `{ref}` but skills/dev/{ref}/ and .agents/{ref}.md do not exist")

    # README.md is the human-facing list and must cover every skill; CLAUDE.md deliberately
    # does not repeat them (the descriptions are already in the always-loaded skill listing).
    readme = (ROOT / "README.md").read_text()
    for d in all_skills:
        if not re.search(rf"\*\*{d}\*\*|\[{d}\]", readme):
            err(ROOT / "README.md", f"does not list skill `{d}`")
    for doc in ("CLAUDE.md", "README.md"):
        text = (ROOT / doc).read_text()
        for a in sorted(agent_names):
            if a not in text:
                err(ROOT / doc, f"does not mention agent `{a}`")

    # every "<N> skills" claim across the docs and manifests must match reality
    for doc in ("CLAUDE.md", "README.md", "index.html", ".claude-plugin/plugin.json", ".claude-plugin/marketplace.json"):
        path = ROOT / doc
        for m in re.finditer(r"(\d+) skills", path.read_text()):
            if int(m.group(1)) != len(all_skills):
                err(path, f"claims `{m.group(0)}` but there are {len(all_skills)}")

    # plugin.json and marketplace.json must exist, parse, and agree on the description
    plugin_path = ROOT / ".claude-plugin" / "plugin.json"
    market_path = ROOT / ".claude-plugin" / "marketplace.json"
    try:
        plugin = json.loads(plugin_path.read_text())
        market = json.loads(market_path.read_text())
        if plugin.get("description") != market["plugins"][0].get("description"):
            err(market_path, "plugin description out of sync with plugin.json")
        # the skills array is the load path — a skill missing from it silently never loads
        listed = set(plugin.get("skills", []))
        actual = {f"./skills/dev/{d}" for d in skill_dirs} | {f"./skills/misc/{d}" for d in misc_dirs}
        for missing in sorted(actual - listed):
            err(plugin_path, f"skills array missing `{missing}` — it will not load")
        for stale in sorted(listed - actual):
            err(plugin_path, f"skills array lists `{stale}` but that directory does not exist")
    except (OSError, json.JSONDecodeError, KeyError, IndexError) as e:
        err(plugin_path, f"manifest problem: {e}")

    # hooks run on every session — a broken path or unparseable file breaks startup silently
    hooks_path = ROOT / "hooks" / "hooks.json"
    if hooks_path.exists():
        try:
            hooks = json.loads(hooks_path.read_text())
            for event, matchers in hooks.get("hooks", {}).items():
                for hook in (h for m in matchers for h in m.get("hooks", [])):
                    for script in re.findall(r"\$\{CLAUDE_PLUGIN_ROOT\}/(\S+?)[\"']", hook.get("command", "")):
                        if not (ROOT / script).exists():
                            err(hooks_path, f"{event} hook points at `{script}` which does not exist")
        except (OSError, json.JSONDecodeError, AttributeError) as e:
            err(hooks_path, f"hooks problem: {e}")

    check_statusline()

    if errors:
        print("\n".join(errors))
        print(f"\n{len(errors)} finding(s)")
        sys.exit(1)
    print(f"OK — {len(all_skills)} skills validated ({len(skill_dirs)} dev, {len(misc_dirs)} misc)")


if __name__ == "__main__":
    main()
