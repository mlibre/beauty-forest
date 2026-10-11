#!/usr/bin/env python3
"""Screenshot QA for Beauty Forest captures.

The one analyzer for the PNGs a capture run leaves in /tmp/shots (or the
directory named on the command line). It replaces five overlapping probes
(analyze.py, analyze2.py, analyze3.py, qa_probe.py, qa_palette.py) that each
measured one slice of the same questions: is the frame bright, warm, colorful,
free of dark voids, and legible?

Usage:
    python3 tools/shot_qa.py [directory] [file ...]

With no arguments it sweeps every .png in /tmp/shots. Named files or a
directory override that default. Read-only: prints a per-file report.
"""
import glob
import os
import sys
from collections import Counter

import numpy as np
from PIL import Image

BANDS = 16


def luminance(rgb: np.ndarray) -> np.ndarray:
    return 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]


def hue_name(deg: float) -> str:
    return ("RED" if deg < 15 or deg >= 345 else "ORANGE" if deg < 45 else
            "YELLOW" if deg < 70 else "YELLOWGRN" if deg < 90 else
            "CHARTREUSE" if deg < 105 else "GREEN" if deg < 160 else
            "CYAN" if deg < 200 else "BLUE" if deg < 260 else
            "VIOLET" if deg < 300 else "MAGENTA")


def _hue(packed_value: int) -> float:
    r = ((packed_value // 1024) * 8 + 4) / 255.0
    g = (((packed_value // 32) % 32) * 8 + 4) / 255.0
    b = ((packed_value % 32) * 8 + 4) / 255.0
    mx, mn = max(r, g, b), min(r, g, b)
    d = mx - mn
    if d == 0:
        return 0.0
    if mx == r:
        h = ((g - b) / d) % 6
    elif mx == g:
        h = (b - r) / d + 2
    else:
        h = (r - g) / d + 4
    return h * 60.0


def summary(rgb: np.ndarray) -> None:
    """Headline luminance/saturation/warmth table."""
    luma = luminance(rgb)
    mx = rgb.max(axis=2)
    mn = rgb.min(axis=2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1), 0)
    warm = (rgb[..., 0] > rgb[..., 2]).mean() * 100
    print(f"  meanL={luma.mean():6.1f}  p05={np.percentile(luma, 5):5.1f}  "
          f"p50={np.percentile(luma, 50):5.1f}  p95={np.percentile(luma, 95):5.1f}")
    print(f"  dark: <32={(luma < 32).mean() * 100:5.2f}%  <20={(luma < 20).mean() * 100:5.2f}%  "
          f"<48={(luma < 48).mean() * 100:5.2f}%   meanSat={sat.mean() * 100:4.1f}%  warm={warm:4.1f}%")


def voids(rgb: np.ndarray) -> None:
    """Flat dark tiles and hard row jumps: the void detector."""
    luma = luminance(rgb)
    height, width = luma.shape
    tile = 40
    flat_dark, total, worst = 0, 0, []
    for row in range(0, height - tile, tile):
        for col in range(0, width - tile, tile):
            block = luma[row:row + tile, col:col + tile]
            total += 1
            if block.std() < 6 and block.mean() < 45:
                flat_dark += 1
                worst.append((block.mean(), col, row))
    worst.sort()
    where = ", ".join(f"({x},{y})L{m:.0f}" for m, x, y in worst[:5])
    print(f"  flat&dark tiles: {flat_dark}/{total} ({flat_dark / max(1, total) * 100:.2f}%)  {where}")
    rowmean = luma.mean(axis=1)
    jumps = [(y, round(float(rowmean[y]), 1), round(float(rowmean[y + 1]), 1))
             for y in range(height - 1) if abs(rowmean[y + 1] - rowmean[y]) > 6]
    print(f"  row L-jumps>6: {jumps[:10]}{' ...' if len(jumps) > 10 else ''}")
    bands = [luma[r * height // BANDS:(r + 1) * height // BANDS].mean() for r in range(BANDS)]
    print("  row bands: " + " ".join(f"{b:4.0f}" for b in bands))


def palette(rgb: np.ndarray) -> None:
    """Exact dominant colors, 5 bits per channel."""
    q = (rgb.astype(np.int32) >> 3)
    packed = (q[..., 0] * 1024 + q[..., 1] * 32 + q[..., 2]).ravel()
    counts = Counter(packed.tolist())
    total = packed.size
    top = "  ".join("#%02x%02x%02x(%s %.1f%%)" % (
        (v // 1024) * 8 + 4, ((v // 32) % 32) * 8 + 4, (v % 32) * 8 + 4,
        hue_name(_hue(v)), c * 100.0 / total)
        for v, c in counts.most_common(6))
    print("  palette: " + top)


def report(path: str) -> None:
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(np.float32)
    print(f"\n=== {os.path.basename(path)}  {rgb.shape[1]}x{rgb.shape[0]} ===")
    summary(rgb)
    voids(rgb)
    palette(rgb)


def main() -> None:
    targets = sys.argv[1:]
    if not targets:
        targets = ["/tmp/shots"]
    files: list[str] = []
    for target in targets:
        if os.path.isdir(target):
            files.extend(sorted(glob.glob(os.path.join(target, "*.png"))))
        else:
            files.append(target)
    if not files:
        print("no screenshots found; capture some first (see docs/TESTING.md)")
        return
    for path in files:
        try:
            report(path)
        except Exception as error:  # a corrupt PNG must not kill the sweep
            print(f"\n=== {os.path.basename(path)} ===\n  unreadable: {error}")


if __name__ == "__main__":
    main()
