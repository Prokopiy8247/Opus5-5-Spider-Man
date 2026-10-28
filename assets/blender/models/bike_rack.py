"""Bike racks: v1 inverted-U hoop pair, v2 wave rack, v3 single hoop with cross bar."""
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/bike_rack.glb"

STEEL = "#4A5054"


def _hoop(b, x, w=0.72, h=0.85, r=0.03, col=STEEL):
    b.cyl(0.07, 0.03, (x - w / 2, 0, 0), m=1, col=col, seg=10)
    b.cyl(0.07, 0.03, (x + w / 2, 0, 0), m=1, col=col, seg=10)
    b.pipe((x - w / 2, 0, 0), (x - w / 2, 0, h - 0.12), r, m=0, col=col, seg=8)
    b.pipe((x + w / 2, 0, 0), (x + w / 2, 0, h - 0.12), r, m=0, col=col, seg=8)
    steps = 6
    pts = [(x + math.cos(math.pi * i / steps) * w / 2, 0, h - 0.12 + math.sin(math.pi * i / steps) * 0.12)
           for i in range(steps + 1)]
    for p0, p1 in zip(pts, pts[1:]):
        b.pipe(p0, p1, r, m=0, col=col, seg=8)


def _v1(b):
    _hoop(b, -0.45)
    _hoop(b, 0.45)


def _v2(b):
    col = "#3C6B4A"
    n = 10
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append((-1.1 + 2.2 * t, 0, 0.1 + 0.42 * (1 - math.cos(t * math.tau * 1.5)) / 2 + 0.2))
    for p0, p1 in zip(pts, pts[1:]):
        b.pipe(p0, p1, 0.028, m=0, col=col, seg=8)
    for x in (-1.1, 0.0, 1.1):
        b.pipe((x, 0, 0), (x, 0, 0.35), 0.028, m=0, col=col, seg=8)
        b.cyl(0.08, 0.03, (x, 0, 0), m=1, col=col, seg=10)


def _v3(b):
    _hoop(b, 0.0, w=0.9, h=0.95)
    b.pipe((-0.45, 0, 0.5), (0.45, 0, 0.5), 0.026, m=0, col=STEEL, seg=8)


def build():
    m = [_kit.mat("Rack_Steel", rough=0.4, metal=0.7), _kit.mat("Rack_Base", rough=0.6, metal=0.3)]
    return _kit.variants("bike_rack", m, [_v1, _v2, _v3], spacing=3.0)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
