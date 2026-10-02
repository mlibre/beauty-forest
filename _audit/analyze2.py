import glob, os
import numpy as np
from PIL import Image

files = sorted(glob.glob("/tmp/shots/*.png"))

print("=== ROW-MEAN LUMINANCE PROFILE (16 bands) — finds sky/horizon/void bands ===")
for f in files:
    a = np.asarray(Image.open(f).convert("L")).astype(np.float32)
    H, W = a.shape
    prof = [a[r*H//16:(r+1)*H//16].mean() for r in range(16)]
    print(f"{os.path.basename(f):22} " + " ".join(f"{p:5.0f}" for p in prof))

print("\n=== COL-MEAN LUMINANCE PROFILE (16 bands, L->R) ===")
for f in files:
    a = np.asarray(Image.open(f).convert("L")).astype(np.float32)
    H, W = a.shape
    prof = [a[:, c*W//16:(c+1)*W//16].mean() for c in range(16)]
    print(f"{os.path.basename(f):22} " + " ".join(f"{p:5.0f}" for p in prof))

print("\n=== FLAT / VOID PATCH DETECTION: 40x40 tiles that are near-uniform and dark ===")
for f in files:
    a = np.asarray(Image.open(f).convert("RGB")).astype(np.float32)
    L = 0.2126*a[...,0]+0.7152*a[...,1]+0.0722*a[...,2]
    H, W = L.shape
    ts = 40
    flatdark = 0; total = 0
    worst = []
    for r in range(0, H-ts, ts):
        for c in range(0, W-ts, ts):
            blk = L[r:r+ts, c:c+ts]
            total += 1
            if blk.std() < 6 and blk.mean() < 45:
                flatdark += 1
                worst.append((blk.mean(), blk.std(), c, r))
    worst.sort()
    loc = ", ".join(f"({x},{y})L{m:.0f}" for m, s, x, y in worst[:6])
    print(f"{os.path.basename(f):22} flat&dark {flatdark:3d}/{total:4d} tiles ({flatdark/total*100:5.2f}%)  {loc}")

print("\n=== BORDER STRIP LUMINANCE (clipped-content / hard-edge check) ===")
for f in files:
    a = np.asarray(Image.open(f).convert("L")).astype(np.float32)
    H, W = a.shape
    parts = [("top8", a[:8]), ("bot8", a[-8:]), ("left8", a[:, :8]), ("right8", a[:, -8:])]
    txt = "  ".join("%s=%5.1f(sd%5.1f)" % (k, v.mean(), v.std()) for k, v in parts)
    print("%-22s %s" % (os.path.basename(f), txt))

print("\n=== WALKING-SCREEN TEXT CANDIDATES: high-frequency edge density per tile ===")
for f in files:
    if not any(w in f for w in ("walk", "dragon", "roost")):
        continue
    a = np.asarray(Image.open(f).convert("L")).astype(np.float32)
    H, W = a.shape
    gx = np.abs(np.diff(a, axis=1))[:, :-1]
    ed = gx > 26
    ts = 160
    hits = []
    for r in range(0, H-ts+1, ts//2):
        for c in range(0, W-ts+1, ts//2):
            blk = ed[r:r+ts, c:c+ts]
            dens = blk.mean()
            if dens > 0.10:
                hits.append((dens, c, r))
    hits.sort(reverse=True)
    print(f"{os.path.basename(f):22} {len(hits):3d} tiles >10% edge density; top: " +
          ", ".join(f"({x},{y}){d*100:.0f}%" for d, x, y in hits[:8]))