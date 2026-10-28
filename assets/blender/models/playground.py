"""Playground set: v1 swing frame + slide tower, v2 climbing frame with monkey bars and spring seats."""
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/park/playground.glb"

FRAME = "#2E6B8C"
ACCENT = "#D8A420"


def _swings_and_slide(b):
    # swing frame
    h, w = 2.4, 3.2
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.pipe((sx * w / 2, sy * 0.8, 0), (sx * (w / 2 - 0.25), 0, h), 0.055, m=0, col=FRAME, seg=8)
            b.cyl(0.14, 0.04, (sx * w / 2, sy * 0.8, 0), m=0, col=FRAME, seg=10)
    b.pipe((-w / 2 + 0.25, 0, h), (w / 2 - 0.25, 0, h), 0.06, m=0, col=FRAME, seg=10)
    for x in (-0.85, 0.85):
        for sy in (-1, 1):
            b.pipe((x + sy * 0.2, 0, h - 0.05), (x + sy * 0.2, 0, 0.55), 0.012, m=1, col="#3A3D40", seg=5)
        b.box((0.5, 0.2, 0.05), (x, 0, 0.5), m=1, col=ACCENT, bevel=0.012)
    # slide tower
    tx = 3.2
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.pipe((tx + sx * 0.6, sy * 0.6, 0), (tx + sx * 0.6, sy * 0.6, 1.9), 0.05, m=0,
                   col=FRAME, seg=8)
    b.box((1.4, 1.4, 0.08), (tx, 0, 1.3), m=1, col=ACCENT, bevel=0.015)                 # deck
    b.box((1.4, 1.4, 0.1), (tx, 0, 2.0), m=0, col=FRAME, bevel=0.02, rot=(0, 0, 0))     # roof
    b.box((1.1, 2.6, 0.07), (tx, -1.9, 0.75), m=1, col=ACCENT, bevel=0.015, rot=(27, 0, 0))  # slide bed
    for sx in (-1, 1):
        b.box((0.07, 2.6, 0.22), (tx + sx * 0.55, -1.9, 0.82), m=1, col=ACCENT, bevel=0.012,
              rot=(27, 0, 0))
    for i in range(4):                                                                   # ladder
        b.pipe((tx - 0.6, 0.62, 0.3 + i * 0.33), (tx + 0.6, 0.62, 0.3 + i * 0.33), 0.025,
               m=0, col=FRAME, seg=6)


def _climber(b):
    # cube climbing frame
    s, h = 2.4, 1.9
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.pipe((sx * s / 2, sy * s / 2, 0), (sx * s / 2, sy * s / 2, h), 0.05, m=0, col=FRAME, seg=8)
            b.cyl(0.13, 0.04, (sx * s / 2, sy * s / 2, 0), m=0, col=FRAME, seg=10)
    for z in (0.7, h):
        for sx in (-1, 1):
            b.pipe((sx * s / 2, -s / 2, z), (sx * s / 2, s / 2, z), 0.04, m=0, col=FRAME, seg=8)
            b.pipe((-s / 2, sx * s / 2, z), (s / 2, sx * s / 2, z), 0.04, m=0, col=FRAME, seg=8)
    for i in range(6):                                                                   # monkey bars
        y = -s / 2 + 0.2 + i * (s - 0.4) / 5
        b.pipe((-s / 2, y, h), (s / 2, y, h), 0.025, m=1, col=ACCENT, seg=6)
    for i in range(5):                                                                   # climbing net
        t = i / 4
        b.pipe((-s / 2 + s * t, -s / 2, 0.08), (-s / 2 + s * t, -s / 2, 0.7), 0.014, m=1,
               col="#3A3D40", seg=5)
    for i, (cx, cy) in enumerate(((-1.9, 1.5), (1.9, -1.5))):                            # spring riders
        b.cyl(0.18, 0.05, (cx, cy, 0), m=0, col=FRAME, seg=12, bevel=0.01)
        b.cyl(0.09, 0.4, (cx, cy, 0.05), m=1, col=ACCENT, seg=10)
        b.blob(0.3, (cx, cy, 0.62), m=1, col="#C4452E", sub=1, scale=(1.5, 0.8, 0.6),
               rot=(0, 0, 20 * (i + 1)))
        b.pipe((cx - 0.26, cy, 0.78), (cx + 0.26, cy, 0.78), 0.022, m=0, col=FRAME, seg=6)


def build():
    m = [_kit.mat("Play_Frame", rough=0.45, metal=0.4), _kit.mat("Play_Accent", rough=0.5)]
    return _kit.variants("playground", m, [_swings_and_slide, _climber], spacing=9.0)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits={"": (150, 4500)})
