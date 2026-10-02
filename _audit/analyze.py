import glob, os
from PIL import Image
import numpy as np

files = sorted(glob.glob("/tmp/shots/*.png"))
hdr = f"{'file':22} {'size':11} {'meanL':>6} {'p05':>5} {'p50':>5} {'p95':>5} {'<32%':>6} {'<20%':>6} {'<48%':>6} {'meanS':>6} {'warm%':>6}"
print(hdr)
for f in files:
    im = Image.open(f).convert("RGB")
    a = np.asarray(im).astype(np.float32)
    L = 0.2126*a[...,0]+0.7152*a[...,1]+0.0722*a[...,2]
    mx = a.max(axis=2); mn = a.min(axis=2)
    S = np.where(mx > 0, (mx-mn)/np.maximum(mx, 1), 0)
    warm = (a[...,0] > a[...,2]).mean()*100
    print(f"{os.path.basename(f):22} {im.size[0]}x{im.size[1]:<6} {L.mean():6.1f} "
          f"{np.percentile(L,5):5.1f} {np.percentile(L,50):5.1f} {np.percentile(L,95):5.1f} "
          f"{(L<32).mean()*100:6.2f} {(L<20).mean()*100:6.2f} {(L<48).mean()*100:6.2f} "
          f"{S.mean()*100:6.1f} {warm:6.1f}")

print("\n=== 4x4 grid mean luminance per image (locates dark regions) ===")
for f in files:
    im = Image.open(f).convert("L")
    a = np.asarray(im).astype(np.float32)
    H, W = a.shape
    print("\n" + os.path.basename(f) + f"  (meanL={a.mean():.1f})   rows top->bottom, cols left->right")
    for r in range(4):
        row = []
        for c in range(4):
            blk = a[r*H//4:(r+1)*H//4, c*W//4:(c+1)*W//4]
            row.append(f"{blk.mean():5.1f}/{((blk<32).mean()*100):4.1f}%")
        print("   " + "  ".join(row))