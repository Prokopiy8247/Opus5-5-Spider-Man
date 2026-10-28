"""Cast-iron tree pit grate (flat, sits at sidewalk level): v1 square radial, v2 round, v3 square with guard ring."""
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/tree_grate.glb"

IRON = "#33373B"


def _square(b, s=1.5, guard=False):
    for sx in (-1, 1):
        b.box((s, 0.12, 0.05), (0, sx * (s / 2 - 0.06), 0.025), m=0, col=IRON, bevel=0.008)
        b.box((0.12, s - 0.24, 0.05), (sx * (s / 2 - 0.06), 0, 0.025), m=0, col=IRON, bevel=0.008)
    b.cyl(0.26, 0.05, (0, 0, 0), m=0, col=IRON, seg=12, bevel=0.006)
    for i in range(12):
        a = i / 12 * math.tau
        b.box((s / 2 - 0.3, 0.05, 0.04), ((math.cos(a) * (s / 2 - 0.1)) / 2 + math.cos(a) * 0.1,
                                          (math.sin(a) * (s / 2 - 0.1)) / 2 + math.sin(a) * 0.1, 0.02),
              m=0, col=IRON, bevel=0.005, rot=(0, 0, math.degrees(a)))
    if guard:
        for i in range(8):
            a = i / 8 * math.tau
            b.pipe((math.cos(a) * 0.5, math.sin(a) * 0.5, 0.04),
                   (math.cos(a) * 0.5, math.sin(a) * 0.5, 0.62), 0.016, m=1, col="#4A4E52", seg=6)
        for z in (0.3, 0.6):
            b.cyl(0.5, 0.022, (0, 0, z), m=1, col="#4A4E52", r2=0.5, seg=16)


def _round(b):
    b.cyl(0.78, 0.05, (0, 0, 0), m=0, col=IRON, r2=0.78, seg=20, bevel=0.006)
    b.cyl(0.3, 0.07, (0, 0, -0.01), m=1, col="#26292C", r2=0.3, seg=16)
    for i in range(16):
        a = i / 16 * math.tau
        b.box((0.44, 0.045, 0.045), (math.cos(a) * 0.52, math.sin(a) * 0.52, 0.035), m=1,
              col="#26292C", bevel=0.004, rot=(0, 0, math.degrees(a)))


def build():
    m = [_kit.mat("Grate_Iron", rough=0.6, metal=0.5), _kit.mat("Grate_Trim", rough=0.5, metal=0.5)]
    return _kit.variants("tree_grate", m, [lambda b: _square(b), _round,
                                           lambda b: _square(b, guard=True)], spacing=2.0)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
