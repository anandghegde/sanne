#!/usr/bin/env python3
"""Render Sanne's app icon (13f: three-finger swipe) to PNG + .icns.

The mark is three cream fingertips on a rising diagonal, each leaving a
horizontal motion dash. Full-bleed clay field — macOS applies the squircle.
"""
from __future__ import annotations

import shutil
import subprocess
import tempfile
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "Resources"
MASTER = OUT_DIR / "AppIcon.png"
ICNS = OUT_DIR / "AppIcon.icns"

SIZE = 1024
CLAY = (194, 82, 64)  # #C25240
CREAM = (244, 235, 218)  # #F4EBDA

# Geometry in a 1024 canvas. y grows down.
DOT_R = 74
DASH_W = 252
DASH_H = 40
GAP = 44  # dot edge → dash
STAGGER_X = 178
STAGGER_Y = 176


def faded_dash(w: int, h: int, *, hold: float = 0.30) -> Image.Image:
    overlay = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    ImageDraw.Draw(overlay).rounded_rectangle(
        [0, 0, w - 1, h - 1], radius=h / 2, fill=CREAM + (255,)
    )
    grad = Image.new("L", (w, h))
    px = grad.load()
    last = max(w - 1, 1)
    for x in range(w):
        t = x / last
        if t < hold:
            a = 255
        else:
            a = int(255 * (1.0 - (t - hold) / (1.0 - hold)))
        for y in range(h):
            px[x, y] = a
    alpha = ImageChops.multiply(overlay.split()[-1], grad)
    overlay.putalpha(alpha)
    return overlay


def render(size: int = SIZE) -> Image.Image:
    s = size / SIZE
    img = Image.new("RGBA", (size, size), CLAY + (255,))

    r = DOT_R * s
    dash_w = max(int(DASH_W * s), 3)
    # Keep motion dashes readable in the Dock / Finder list.
    min_dash_h = 3 if size >= 32 else 2
    dash_h = max(int(DASH_H * s), min_dash_h)
    gap = GAP * s
    sx = STAGGER_X * s
    sy = STAGGER_Y * s
    hold = 0.55 if size <= 64 else 0.30

    width = 2 * sx + 2 * r + gap + dash_w
    height = 2 * sy + 2 * r
    # Optical shift: dashes pull mass right.
    ox = (size - width) / 2 - 12 * s
    oy = (size - height) / 2 - 6 * s

    dash = faded_dash(dash_w, dash_h, hold=hold)
    draw = ImageDraw.Draw(img)
    for i in range(3):
        cx = ox + r + i * sx
        cy = oy + height - r - i * sy
        x0, y0 = cx - r, cy - r
        draw.ellipse([x0, y0, cx + r, cy + r], fill=CREAM + (255,))
        dx = int(round(cx + r + gap))
        dy = int(round(cy - dash_h / 2))
        img.alpha_composite(dash, (dx, dy))
    return img.convert("RGB")


def write_icns(dest: Path) -> None:
    iconutil = shutil.which("iconutil")
    if not iconutil:
        raise SystemExit("iconutil is required (macOS)")

    names = {
        "icon_16x16.png": 16,
        "icon_16x16@2x.png": 32,
        "icon_32x32.png": 32,
        "icon_32x32@2x.png": 64,
        "icon_128x128.png": 128,
        "icon_128x128@2x.png": 256,
        "icon_256x256.png": 256,
        "icon_256x256@2x.png": 512,
        "icon_512x512.png": 512,
        "icon_512x512@2x.png": 1024,
    }
    with tempfile.TemporaryDirectory() as tmp:
        iconset = Path(tmp) / "AppIcon.iconset"
        iconset.mkdir()
        for name, px in names.items():
            render(px).save(iconset / name, "PNG")
        subprocess.run(
            [iconutil, "-c", "icns", str(iconset), "-o", str(dest)],
            check=True,
            capture_output=True,
        )


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    render().save(MASTER, "PNG")
    write_icns(ICNS)
    print(f"wrote {MASTER.relative_to(ROOT)}")
    print(f"wrote {ICNS.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
