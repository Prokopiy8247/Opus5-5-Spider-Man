"""Sidewalk / road vent grating flush with the surface (v1 subway grate 1.2x0.8, v2 round vent, v3 long strip)."""
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/road/steam_vent.glb"

IRON = "#3C4044"
DARK = "#16181A"


def _grate(w, d, bars):
    def f(b):
        b.box((w + 0.1, d + 0.1, 0.04), (0, 0, 0.0), m=0, col=IRON, bevel=0.008)       # frame
        b.box((w - 0.04, d - 0.04, 0.06), (0, 0, -0.03), m=1, col=DARK, bevel=0.005)   # void
        for i in range(bars):
            y = -d / 2 + 0.06 + i * (d - 0.12) / max(1, bars - 1)
            b.box((w - 0.06, 0.035, 0.03), (0, y, 0.01), m=0, col=IRON, bevel=0.004)
        for sx in (-1, 1):
            b.box((0.05, d - 0.06, 0.03), (sx * (w / 2 - 0.05), 0, 0.01), m=0, col=IRON, bevel=0.004)
    return f


def _round(b):
    b.cyl(0.42, 0.04, (0, 0, -0.01), m=0, col=IRON, seg=18, bevel=0.006)
    b.cyl(0.36, 0.05, (0, 0, -0.03), m=1, col=DARK, seg=18)
    for i in range(10):
        a = i / 10 * math.tau
        b.box((0.3, 0.04, 0.03), (math.cos(a) * 0.0, math.sin(a) * 0.0, 0.012), m=0, col=IRON,
              bevel=0.004, rot=(0, 0, math.degrees(a)))
    b.cyl(0.08, 0.05, (0, 0, 0.0), m=0, col=IRON, seg=12)


def build():
    m = [_kit.mat("Vent_Iron", rough=0.65, metal=0.5), _kit.mat("Vent_Void", rough=0.9)]
    return _kit.variants("steam_vent", m, [_grate(1.2, 0.8, 11), _round, _grate(2.0, 0.5, 7)],
                         spacing=2.4)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
