"""Litter baskets: v1 perforated wire basket (vertical slats + rings), v2 green lidded can with dome top."""
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/trash_can.glb"


def _wire(b):
    col = "#3C5A3E"
    b.cyl(0.24, 0.04, (0, 0, 0), m=0, col=col, seg=12)
    for z in (0.05, 0.4, 0.8):
        b.cyl(0.29, 0.035, (0, 0, z), m=0, col=col, seg=12)
    for i in range(14):
        a = i / 14 * math.tau
        b.pipe((math.cos(a) * 0.24, math.sin(a) * 0.24, 0.04), (math.cos(a) * 0.29, math.sin(a) * 0.29, 0.83),
               0.012, m=0, col=col, seg=4)
    b.cyl(0.27, 0.03, (0, 0, 0.6), m=1, col="#2A2A2A", seg=12)                        # bag rim inside


def _lidded(b):
    col = "#2E4A30"
    b.cyl(0.27, 0.86, (0, 0, 0), m=0, col=col, r2=0.3, seg=14)
    b.cyl(0.31, 0.06, (0, 0, 0.86), m=0, col=col, seg=14)
    b.cyl(0.3, 0.22, (0, 0, 0.92), m=0, col=col, r2=0.12, seg=14)                    # dome
    b.box((0.3, 0.06, 0.14), (0, -0.26, 0.98), m=1, col="#141414", bevel=0.01, rot=(30, 0, 0))  # slot
    for z in (0.15, 0.7):
        b.cyl(0.3, 0.04, (0, 0, z), m=1, col="#9A9A92", seg=14)                       # bands


def build():
    m = [_kit.mat("Paint", rough=0.55, metal=0.3), _kit.mat("Trim", rough=0.7)]
    return _kit.variants("trash_can", m, [_wire, _lidded], spacing=1.5)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
