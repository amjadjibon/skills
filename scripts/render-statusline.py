#!/usr/bin/env python3
"""Render docs/statusline.png from the status line's real output.

    python3 scripts/render-statusline.py

Reads scripts/statusline-docs.json, pipes it through statusline/statusline.sh, and
draws the resulting ANSI as a PNG on the site's background colour. Rendered rather
than screenshotted so the image can be regenerated whenever the format changes —
a stale screenshot is the failure mode this replaces.

The payload lives in scripts/ rather than statusline/tests/ on purpose: it
interpolates this checkout's path so the image shows a real directory and branch,
which makes it deliberately machine-dependent — the opposite of what a golden
fixture needs.

Update the alt text in README.md and index.html to match; both transcribe the
image for anyone who cannot see it.
"""
import re
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parent.parent
PAYLOAD = ROOT / "scripts" / "statusline-docs.json"
OUT = ROOT / "docs" / "statusline.png"
FONT = "/System/Library/Fonts/Menlo.ttc"

FG, BG = (230, 237, 243), (13, 17, 23)  # index.html's --text and --bg
SIZE, PAD, LEAD = 26, 26, 12
# the clock is pinned so the reset countdowns render identically on every run
NOW = "1800000000"


def rgb(index):
    """xterm-256 index -> RGB, for the 6x6x6 cube and the greyscale ramp."""
    if 16 <= index <= 231:
        index -= 16
        levels = (0, 95, 135, 175, 215, 255)
        return levels[index // 36], levels[(index % 36) // 6], levels[index % 6]
    if 232 <= index <= 255:
        v = 8 + (index - 232) * 10
        return v, v, v
    return FG


def runs(line):
    """Split one ANSI line into (text, colour) runs."""
    out, colour, pos = [], FG, 0
    for m in re.finditer(r"\x1b\[([0-9;]*)m", line):
        if m.start() > pos:
            out.append((line[pos:m.start()], colour))
        c = re.match(r"38;5;(\d+)$", m.group(1))
        colour = rgb(int(c.group(1))) if c else FG
        pos = m.end()
    if pos < len(line):
        out.append((line[pos:], colour))
    return out


def main():
    if not PAYLOAD.exists():
        sys.exit(f"missing {PAYLOAD.relative_to(ROOT)}")
    rendered = subprocess.run(
        ["/bin/bash", str(ROOT / "statusline" / "statusline.sh")],
        # @REPO@ becomes this checkout, so the image shows a real directory and branch
        input=PAYLOAD.read_text().replace("@REPO@", str(ROOT)).encode(),
        env={"PATH": "/usr/bin:/bin:/usr/local/bin:/opt/homebrew/bin",
             "STATUSLINE_NOW": NOW, "COLUMNS": "0"},
        capture_output=True, check=True,
    ).stdout.decode()

    lines = [runs(l) for l in rendered.rstrip("\n").split("\n")]
    font = ImageFont.truetype(FONT, SIZE)
    probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    width = lambda t: probe.textlength(t, font=font)
    ascent, descent = font.getmetrics()
    lh = ascent + descent + LEAD

    w = int(max(sum(width(t) for t, _ in ln) for ln in lines)) + PAD * 2
    h = lh * len(lines) + PAD * 2 - LEAD
    img = Image.new("RGB", (w, h), BG)
    draw = ImageDraw.Draw(img)
    for row, line in enumerate(lines):
        x = PAD
        for text, colour in line:
            draw.text((x, PAD + row * lh), text, font=font, fill=colour)
            x += width(text)
    OUT.parent.mkdir(exist_ok=True)
    img.save(OUT)

    print(f"{OUT.relative_to(ROOT)}  {w}x{h}")
    print("\nalt text should transcribe:")
    for line in lines:
        print("  " + "".join(t for t, _ in line))


if __name__ == "__main__":
    main()
