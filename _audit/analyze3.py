import glob, os
import numpy as np
from PIL import Image

files = sorted(glob.glob("/tmp/shots/*.png"))

print("=== DOMINANT PALETTE (k-means-ish via quantize) + brightness buckets ===")
for f in files:
    im = Image.open(f).convert("RGB")
    q = im.quantize(colors=8, method=Image.MEDIANCUT).convert("RGB")
    cols = q.getcolors(100000)
    cols.sort(reverse=True)
    tot = sum(c for c, _ in cols)
    a = np.asarray(im).astype(np.float32)
    L = 0.2126*a[...,0]+0.7152*a[...,1]+0.0722*a[...,2]
    buckets = {"<32": (L < 32).mean(), "32-64": ((L >= 32) & (L < 64)).mean(),
               "64-128": ((L >= 64) & (L < 128)).mean(), "128-192": ((L >= 128) & (L < 192)).mean(),
               "192+": (L >= 192).mean()}
    bs = "  ".join("%s=%4.0f%%" % (k, v * 100) for k, v in buckets.items())
    print("\n%-22s %s" % (os.path.basename(f), bs))
    print("   palette: " + "  ".join("#%02x%02x%02x(%.0f%%)" % (r, g, b, c / tot * 100) for c, (r, g, b) in cols[:8]))

print("\n\n=== 05_shop REGIONAL MAP: 6x5 grid mean RGB + L ===")
a = np.asarray(Image.open("/tmp/shots/05_shop.png").convert("RGB")).astype(np.float32)
H, W, _ = a.shape
for r in range(5):
    out = []
    for c in range(6):
        blk = a[r*H//5:(r+1)*H//5, c*W//6:(c+1)*W//6]
        Lb = (0.2126*blk[...,0]+0.7152*blk[...,1]+0.0722*blk[...,2]).mean()
        out.append("L%3.0f(%3.0f,%3.0f,%3.0f)" % (Lb, blk[...,0].mean(), blk[...,1].mean(), blk[...,2].mean()))
    print("  r%d  " % r + " ".join(out))

print("\n=== TEXT-CONTRAST CHECK: is UI text legible? (local contrast around bright/dark text) ===")
for f in files:
    im = Image.open(f).convert("L")
    a = np.asarray(im).astype(np.float32)
    # text-like pixels: pixels much darker or much lighter than local median
    from scipy import ndimage  # may fail
    break
print("(skipped scipy)")