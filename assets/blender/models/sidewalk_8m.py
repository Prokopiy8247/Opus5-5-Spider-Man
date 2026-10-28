"""Straight 8 m sidewalk tile: 3.5 m wide walking surface at z=0.15, 0.15 m granite curb, scored joints.

Variants: v1 plain, v2 with a utility cover panel and a tree pit gap.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/road/sidewalk_8m.glb"

L = 8.0
W = 3.5
TOP = 0.15
CONC = "#B4B1A8"
CURB = "#8D8A82"


def _base(b, joints=8):
    # Curb runs along -X edge (street side); walk surface spans X in [-W/2, W/2].
    b.box((W - 0.2, L, TOP), (0.1, 0, TOP / 2), m=0, col=CONC, bevel=0.012)       # slab
    b.box((0.2, L, TOP + 0.15), (-W / 2 + 0.1, 0, (TOP + 0.15) / 2 - 0.075), m=1, col=CURB,
          bevel=0.02)                                                             # curb stone
    b.box((0.06, L, 0.04), (-W / 2 + 0.2, 0, TOP - 0.01), m=1, col=CURB, bevel=0.008)  # curb lip
    for i in range(1, joints):                                                    # scored joints
        y = -L / 2 + i * (L / joints)
        b.box((W - 0.24, 0.05, 0.02), (0.1, y, TOP - 0.005), m=0, col="#9F9C93", bevel=0.004)
    b.box((0.08, L, 0.03), (W / 2 - 0.06, 0, TOP + 0.01), m=0, col="#9F9C93", bevel=0.005)


def _v1(b):
    _base(b)


def _v2(b):
    _base(b, joints=6)
    b.box((0.9, 1.2, 0.04), (0.5, 1.8, TOP + 0.01), m=1, col="#6E6B66", bevel=0.008)   # utility panel
    b.box((1.3, 1.3, 0.05), (0.6, -2.0, TOP - 0.02), m=1, col="#4A4236", bevel=0.01)   # tree pit soil
    for s in (-1, 1):
        b.box((1.4, 0.1, 0.07), (0.6, -2.0 + s * 0.7, TOP + 0.01), m=1, col=CURB, bevel=0.008)
        b.box((0.1, 1.4, 0.07), (0.6 + s * 0.7, -2.0, TOP + 0.01), m=1, col=CURB, bevel=0.008)


def build():
    m = [_kit.mat("Concrete", rough=0.85), _kit.mat("Granite", rough=0.7)]
    return _kit.variants("sidewalk_8m", m, [_v1, _v2], spacing=5.0)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
