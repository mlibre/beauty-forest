#!/usr/bin/env python3
"""Quantitative verification probe for Beauty Forest screenshots 06 and 07."""
import numpy as np
from PIL import Image
from collections import Counter

for fn in ("06_dragon_floor.png", "07_roost_finale.png"):
    p = "/tmp/shots/" + fn
    im = Image.open(p).convert("RGB")
    a = np.asarray(im).astype(np.float32)
    H, W, _ = a.shape
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    L = 0.299 * r + 0.587 * g + 0.114 * b
    mx = a.max(axis=2)
    mn = a.min(axis=2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0.0) * 100.0

    print("=" * 72)
    print(fn, f"{W}x{H}")
    print(f"  mean L={L.mean():.1f}  median L={np.median(L):.1f}")
    print(f"  p1={np.percentile(L,1):.1f} p5={np.percentile(L,5):.1f} "
          f"p95={np.percentile(L,95):.1f} p99={np.percentile(L,99):.1f} max={L.max():.1f}")
    print(f"  pixels L<32: {(L < 32).sum()}  L<48: {(L < 48).sum()}  L<64: {(L < 64).sum()}")
    print(f"  pixels L<80: {(L < 80).sum()} ({(L<80).mean()*100:.2f}%)")
    print(f"  pixels L>192: {(L > 192).mean()*100:.1f}%   >224: {(L>224).mean()*100:.1f}%  >250: {(L>250).mean()*100:.2f}%")
    print(f"  mean sat={sat.mean():.1f}%")
    # channel balance -> green vs yellow vs blue
    print(f"  mean R={r.mean():.1f} G={g.mean():.1f} B={b.mean():.1f}   "
          f"R-B={r.mean()-b.mean():.1f}  G-(R+B)/2={g.mean()-(r.mean()+b.mean())/2:.1f}")
    # hue of dominant colors
    q = (a // 16).astype(np.int32)
    packed = (q[..., 0] * 64 + q[..., 1] * 8 + q[..., 2]).ravel()
    cnt = Counter(packed.tolist())
    print("  top-10 dominant quantized colors:")
    tot = packed.size
    for v, c in cnt.most_common(10):
        rr, gg, bb = (v // 64) * 16 + 8, ((v // 8) % 8) * 16 + 8, (v % 8) * 16 + 8
        # hue
        import colorsys
        h, s, vv = colorsys.rgb_to_hsv(rr / 255, gg / 255, bb / 255)
        hd = h * 360
        name = ("RED" if hd < 20 or hd >= 345 else "ORANGE" if hd < 45 else
                "YELLOW" if hd < 70 else "YELLOWGRN" if hd < 85 else
                "CHARTREUSE" if hd < 100 else "GREEN" if hd < 160 else
                "CYAN" if hd < 200 else "BLUE" if hd < 260 else "VIOLET" if hd < 300 else "MAGENTA")
        print(f"    #{rr:02x}{gg:02x}{bb:02x} hue={hd:5.1f} sat={s*100:4.0f}% {c*100/tot:5.2f}%")
    # 16x16 row profile
    print("  row bands (16, top->bottom):",
          " ".join(f"{L[i*H//16:(i+1)*H//16].mean():.0f}" for i in range(16)))
    print("  col bands (16, left->right):",
          " ".join(f"{L[:, i*W//16:(i+1)*W//16].mean():.0f}" for i in range(16)))
    # darkest 5 row bands with y ranges
    rb = [L[i*H//16:(i+1)*H//16].mean() for i in range(16)]
    worst = sorted(range(16), key=lambda i: rb[i])[:3]
    print("  darkest row bands:", [(i, int(i*H/16), int((i+1)*H/16), round(rb[i], 1)) for i in worst])
    cb = [L[:, i*W//16:(i+1)*W//16].mean() for i in range(16)]
    worstc = sorted(range(16), key=lambda i: cb[i])[:3]
    print("  darkest col bands:", [(i, int(i*W/16), int((i+1)*W/16), round(cb[i], 1)) for i in worstc])
