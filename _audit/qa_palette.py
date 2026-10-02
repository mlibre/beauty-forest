#!/usr/bin/env python3
"""Correct dominant-palette extraction (5 bits/channel) + structure probes."""
import numpy as np
from PIL import Image
import colorsys

for fn in ("06_dragon_floor.png", "07_roost_finale.png"):
    a = np.asarray(Image.open("/tmp/shots/" + fn).convert("RGB")).astype(np.int32)
    H, W, _ = a.shape
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    L = 0.299 * r + 0.587 * g + 0.114 * b

    q = (a >> 3)  # 0..31
    packed = (q[..., 0] * 1024 + q[..., 1] * 32 + q[..., 2]).ravel()
    vals, counts = np.unique(packed, return_counts=True)
    order = np.argsort(-counts)
    tot = packed.size
    print("=" * 74)
    print(fn, " true dominant colors (exact mode, 8-level bin):")
    for idx in order[:8]:
        v = int(vals[idx])
        rr, gg, bb = ((v // 1024) * 8 + 4), (((v // 32) % 32) * 8 + 4), ((v % 32) * 8 + 4)
        h, s, vv = colorsys.rgb_to_hsv(rr / 255, gg / 255, bb / 255)
        hd = h * 360
        nm = ("RED" if hd < 15 or hd >= 345 else "ORANGE" if hd < 45 else
              "YELLOW" if hd < 70 else "YELLOWGRN" if hd < 90 else
              "CHARTREUSE" if hd < 105 else "GREEN" if hd < 160 else
              "CYAN" if hd < 200 else "BLUE" if hd < 260 else "VIOLET" if hd < 300 else "MAGENTA")
        print(f"   #{rr:02x}{gg:02x}{bb:02x} hue={hd:6.1f} ({nm:9s}) sat={s*100:3.0f}%  {counts[idx]*100/tot:5.2f}%")

    # hue/sat character of the frame excluding near-white UI
    print(f"\n  frame hue (mean, px-weighted):")
    mx, mn = a.max(axis=2), a.min(axis=2)
    d = np.maximum(mx - mn, 1)
    hh = np.zeros_like(mx, dtype=np.float32)
    nz = d > 0
    m = (mx == r) & nz; hh[m] = ((gg - bb)[m] / d[m]) % 6
    m = (mx == g) & nz; hh[m] = ((bb - rr)[m] / d[m]) + 2
    m = (mx == b) & nz; hh[m] = ((rr - gg)[m] / d[m]) + 4
    hh *= 60
    satp = np.where(mx > 0, d / np.maximum(mx, 1e-6), 0)
    w = (satp > 0.25) & (L > 40)          # colorful, not-black pixels only
    print(f"    colored px (sat>25%, L>40): {w.mean()*100:.1f}% of frame, mean hue={np.angle(np.exp(1j*np.radians(hh[w])).mean(),deg=True)%360:.1f} deg")

    # blue/sky check: how much of the frame is sky-like (blue-ish, bright, upper)?
    upper = slice(0, H // 2)
    sky = (b > r + 10) & (L > 120)
    print(f"    blue-dominant px total={sky.mean()*100:.2f}%  upper-half={sky[upper].mean()*100:.2f}%")

    # contrast / blown-out structure
    l8 = np.round(L / 8) * 8
    hist = np.bincount(np.clip(l8.ravel().astype(int), 0, 31), minlength=32)
    print("    L histogram (L:%, 8-px buckets from 0):")
    print("      " + " ".join(f"{i*8}:{hist[i]*100/tot:.1f}" for i in range(32) if hist[i] * 100 / tot > 0.4))
    # local contrast in flat regions (washout detector): std of L in 8x8 tiles
    print(f"    8x8 tile L-std: median={np.median([L[i:i+8,j:j+8].std() for i in range(0,H-8,8) for j in range(0,W-8,8)]):.1f} "
          f"p90={np.percentile([L[i:i+8,j:j+8].std() for i in range(0,H-8,8) for j in range(0,W-8,8)],90):.1f}")

    # hard-edged dark mass detection: strong gradient rows in the dark band
    rowmean = L.mean(axis=1)
    jumps = [(int(y), round(float(rowmean[y]), 1), round(float(rowmean[y + 1]), 1)) for y in range(H - 1)
             if abs(rowmean[y + 1] - rowmean[y]) > 6]
    print(f"    rows with >6 L jump top->bottom: {jumps[:14]}{' ...' if len(jumps) > 14 else ''}")
