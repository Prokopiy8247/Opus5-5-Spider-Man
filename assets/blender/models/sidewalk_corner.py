"""Sidewalk corner tile: 90-degree corner with a radiused curb, 3.5 m walk width, top at z=0.15.

Variants: v1 plain corner, v2 corner with a pedestrian ramp notch.
"""
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/road/sidewalk_corner.glb"

W = 3.5
TOP = 0.15
CONC = "#B4B1A8"
CURB = "#8D8A82"


def _make(ramp):
    def f(b):
        # L-shaped slab: arm along +Y and arm along +X, inner corner at origin.
        b.box((W, W, TOP), (W / 2, W / 2, TOP / 2), m=0, col=CONC, bevel=0.012)
        b.box((W, 4.0, TOP), (W / 2, W + 2.0, TOP / 2), m=0, col=CONC, bevel=0.012)
        b.box((4.0, W, TOP), (W + 2.0, W / 2, TOP / 2), m=0, col=CONC, bevel=0.012)
        # radiused curb along the street edges (x=0 and y=0)
        steps = 7
        r = 1.2
        pts = [(r - r * math.cos(math.pi / 2 * i / steps), r - r * math.sin(math.pi / 2 * i / steps))
               for i in range(steps + 1)]
        for p0, p1 in zip(pts, pts[1:]):
            mx, my = (p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2
            ang = math.degrees(math.atan2(p1[1] - p0[1], p1[0] - p0[0]))
            seg = math.dist(p0, p1) + 0.03
            b.box((seg, 0.2, TOP + 0.15), (mx, my, (TOP + 0.15) / 2 - 0.075), m=1, col=CURB,
                  bevel=0.015, rot=(0, 0, ang))
        b.box((0.2, 4.0 + W - r, TOP + 0.15), (0.1, r + (4.0 + W - r) / 2, (TOP + 0.15) / 2 - 0.075),
              m=1, col=CURB, bevel=0.015)
        b.box((4.0 + W - r, 0.2, TOP + 0.15), (r + (4.0 + W - r) / 2, 0.1, (TOP + 0.15) / 2 - 0.075),
              m=1, col=CURB, bevel=0.015)
        for i in (1, 2, 3):
            b.box((W - 0.2, 0.05, 0.02), (W / 2, W + i * 1.0, TOP - 0.005), m=0, col="#9F9C93", bevel=0.004)
            b.box((0.05, W - 0.2, 0.02), (W + i * 1.0, W / 2, TOP - 0.005), m=0, col="#9F9C93", bevel=0.004)
        if ramp:
            b.box((1.6, 1.6, 0.06), (1.5, 1.5, TOP - 0.03), m=1, col="#A5A29A", bevel=0.01,
                  rot=(0, 0, 45))
    return f


def build():
    m = [_kit.mat("Concrete", rough=0.85), _kit.mat("Granite", rough=0.7)]
    return _kit.variants("sidewalk_corner", m, [_make(False), _make(True)], spacing=12.0)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
