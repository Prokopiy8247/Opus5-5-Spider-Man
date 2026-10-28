"""Street planters: v1 square concrete planter with shrub, v2 round, v3 long rectangular with flowers."""
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/planter.glb"

STONE = "#9C978C"


def _soil_and_plants(b, w, d, z, seed, flowers=False):
    b.box((w - 0.16, d - 0.16, 0.05), (0, 0, z - 0.03), m=1, col="#3A2C20", bevel=0.01)
    rnd = __import__("random").Random(seed)
    n = 3 if not flowers else 5
    for i in range(n):
        x = -w / 2 + 0.25 + (w - 0.5) * (i / max(1, n - 1))
        y = rnd.uniform(-d * 0.18, d * 0.18)
        r = rnd.uniform(0.16, 0.24)
        col = "#C44E6E" if flowers and i % 2 else "#3E6B33"
        f = b.blob(r, (x, y, z + r * 0.7), m=1, col=col, sub=1, scale=(1, 1, 0.8),
                   rot=(0, 0, rnd.uniform(0, 90)))
        b.jitter(f, r * 0.15, seed + i)


def _square(b):
    w = d = 0.95
    b.box((w, d, 0.1), (0, 0, 0.05), m=0, col=STONE, bevel=0.02)
    for sx in (-1, 1):
        b.box((w, 0.1, 0.62), (0, sx * (d / 2 - 0.05), 0.4), m=0, col=STONE, bevel=0.025)
        b.box((0.1, d - 0.2, 0.62), (sx * (w / 2 - 0.05), 0, 0.4), m=0, col=STONE, bevel=0.025)
    b.box((w + 0.06, d + 0.06, 0.07), (0, 0, 0.74), m=0, col=STONE, bevel=0.02)
    _soil_and_plants(b, w, d, 0.66, 21)


def _round(b):
    b.cyl(0.52, 0.1, (0, 0, 0), m=0, col=STONE, seg=16, bevel=0.02)
    b.cyl(0.48, 0.6, (0, 0, 0.1), m=0, col=STONE, r2=0.5, seg=16)
    b.cyl(0.42, 0.62, (0, 0, 0.12), m=0, col="#8C877D", r2=0.44, seg=16)
    b.cyl(0.54, 0.07, (0, 0, 0.68), m=0, col=STONE, seg=16, bevel=0.02)
    _soil_and_plants(b, 0.8, 0.8, 0.66, 22)


def _long(b):
    w, d = 1.8, 0.7
    b.box((w, d, 0.1), (0, 0, 0.05), m=0, col="#7A7268", bevel=0.02)
    for sx in (-1, 1):
        b.box((w, 0.09, 0.5), (0, sx * (d / 2 - 0.045), 0.34), m=0, col="#7A7268", bevel=0.02)
        b.box((0.09, d - 0.18, 0.5), (sx * (w / 2 - 0.045), 0, 0.34), m=0, col="#7A7268", bevel=0.02)
    b.box((w + 0.05, d + 0.05, 0.06), (0, 0, 0.62), m=0, col="#7A7268", bevel=0.018)
    _soil_and_plants(b, w, d, 0.56, 23, flowers=True)


def build():
    m = [_kit.mat("Planter_Stone", rough=0.8), _kit.mat("Leaves", rough=0.7)]
    return _kit.variants("planter", m, [_square, _round, _long], spacing=2.2)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits={"": (150, 2600)})
