"""Manhole cover set into the asphalt: ring frame plus patterned lid (v1 radial, v2 waffle, v3 square utility box)."""
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/road/manhole.glb"

IRON = "#3A3D40"
RING = "#2E3134"


def _radial(b):
    b.cyl(0.46, 0.03, (0, 0, -0.005), m=1, col=RING, seg=20, bevel=0.005)
    b.cyl(0.4, 0.035, (0, 0, 0.0), m=0, col=IRON, seg=20, bevel=0.005)
    b.cyl(0.11, 0.045, (0, 0, 0.0), m=0, col=IRON, seg=12)
    for i in range(12):
        a = i / 12 * math.tau
        b.box((0.24, 0.045, 0.012), (math.cos(a) * 0.25, math.sin(a) * 0.25, 0.038), m=0,
              col="#44484B", bevel=0.003, rot=(0, 0, math.degrees(a)))


def _waffle(b):
    b.cyl(0.46, 0.03, (0, 0, -0.005), m=1, col=RING, seg=20, bevel=0.005)
    b.cyl(0.4, 0.035, (0, 0, 0.0), m=0, col=IRON, seg=20, bevel=0.005)
    for ix in range(-2, 3):
        for iy in range(-2, 3):
            if ix * ix + iy * iy > 5:
                continue
            b.box((0.1, 0.1, 0.012), (ix * 0.13, iy * 0.13, 0.038), m=0, col="#44484B", bevel=0.003)
    b.cyl(0.41, 0.012, (0, 0, 0.035), m=0, col="#36393C", r2=0.41, seg=20)


def _square(b):
    b.box((0.78, 0.6, 0.03), (0, 0, -0.005), m=1, col=RING, bevel=0.006)
    b.box((0.7, 0.52, 0.04), (0, 0, 0.0), m=0, col=IRON, bevel=0.006)
    for i in range(3):
        b.box((0.6, 0.08, 0.012), (0, -0.15 + i * 0.15, 0.042), m=0, col="#44484B", bevel=0.003)
    b.cyl(0.03, 0.02, (0.26, 0, 0.042), m=1, col=RING, seg=8)


def build():
    m = [_kit.mat("Iron_Cover", rough=0.6, metal=0.5), _kit.mat("Iron_Frame", rough=0.7, metal=0.4)]
    return _kit.variants("manhole", m, [_radial, _waffle, _square], spacing=1.2)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
