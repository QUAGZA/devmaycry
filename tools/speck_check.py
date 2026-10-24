"""Black-speckle detector for screenshots (the toon-shader normal bug showed up as isolated near-black pixels in lit
areas). A pixel counts as a speck when it is nearly black while at least 7 of its 8 neighbours are clearly lit.
Usage: python tools/speck_check.py build/shots/vis_*.png"""
import sys

import numpy as np
from PIL import Image


def specks(path):
    img = np.asarray(Image.open(path).convert("RGB"), dtype=np.float32) / 255.0
    lum = 0.2126 * img[..., 0] + 0.7152 * img[..., 1] + 0.0722 * img[..., 2]
    dark = lum < 0.07
    lit = lum > 0.25
    n = np.zeros_like(lum, dtype=np.int32)
    for dz in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dz or dx:
                n += np.roll(np.roll(lit, dz, axis=0), dx, axis=1).astype(np.int32)
    sp = dark & (n >= 7)
    sp[:2, :] = False
    sp[-2:, :] = False
    sp[:, :2] = False
    sp[:, -2:] = False
    return int(sp.sum()), lum.size, float((lum < 0.07).mean())


if __name__ == "__main__":
    total = 0
    worst = 0
    for p in sys.argv[1:]:
        c, n, dark = specks(p)
        total += c
        worst = max(worst, c)
        print("%-40s isolated dark pixels: %5d   (%.2f ppm)   dark share %.1f%%" % (p.split("/")[-1], c, c / n * 1e6, dark * 100))
    print("TOTAL isolated dark pixels over %d images: %d, worst image %d" % (len(sys.argv) - 1, total, worst))
