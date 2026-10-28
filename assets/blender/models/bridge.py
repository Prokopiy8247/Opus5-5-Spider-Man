"""Park pond bridge: arched stone deck with parapets (v1 stone arch 8 m, v2 timber plank bridge 7 m)."""
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/park/bridge.glb"

STONE = "#A79F93"
WOOD = "#7A5B39"
IRON = "#33373B"


def _arch_profile(span, rise, steps):
    pts = []
    for i in range(steps + 1):
        t = i / steps
        pts.append((-span / 2 + span * t, rise * math.sin(math.pi * t)))
    return pts


def _stone(b):
    span, rise, w = 8.0, 1.1, 2.6
    pts = _arch_profile(span, rise, 10)
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        xm, zm = (x0 + x1) / 2, (z0 + z1) / 2
        seg = math.dist((x0, z0), (x1, z1)) + 0.05
        ang = math.degrees(math.atan2(z1 - z0, x1 - x0))
        b.box((seg, w, 0.3), (xm, 0, zm + 0.45), m=0, col=STONE, bevel=0.02, rot=(0, -ang, 0))
        for sy in (-1, 1):                                                     # parapets
            b.box((seg, 0.22, 0.65), (xm, sy * (w / 2 - 0.11), zm + 0.9), m=0, col=STONE,
                  bevel=0.025, rot=(0, -ang, 0))
            b.box((seg, 0.3, 0.1), (xm, sy * (w / 2 - 0.11), zm + 1.27), m=0, col=STONE,
                  bevel=0.02, rot=(0, -ang, 0))
    for sx in (-1, 1):                                                         # abutments
        b.box((1.0, w + 0.2, 0.6), (sx * (span / 2 + 0.3), 0, 0.3), m=0, col=STONE, bevel=0.03)
    b.cyl(rise + 0.1, w - 0.3, (0, (w - 0.3) / 2, 0.3), m=1, col="#8B8477", seg=14,
          rot=(90, 0, 0))                                                      # arch soffit face


def _timber(b):
    span, rise, w = 7.0, 0.8, 2.0
    pts = _arch_profile(span, rise, 8)
    for (x0, z0), (x1, z1) in zip(pts, pts[1:]):
        xm, zm = (x0 + x1) / 2, (z0 + z1) / 2
        seg = math.dist((x0, z0), (x1, z1)) + 0.05
        ang = math.degrees(math.atan2(z1 - z0, x1 - x0))
        b.box((seg, w, 0.14), (xm, 0, zm + 0.5), m=0, col=WOOD, bevel=0.012, rot=(0, -ang, 0))
        for sy in (-1, 1):
            b.box((seg, 0.08, 0.08), (xm, sy * (w / 2 - 0.05), zm + 1.5), m=1, col=IRON,
                  bevel=0.01, rot=(0, -ang, 0))
            b.box((seg, 0.06, 0.06), (xm, sy * (w / 2 - 0.05), zm + 1.1), m=1, col=IRON,
                  bevel=0.008, rot=(0, -ang, 0))
    for i, (x, z) in enumerate(pts):
        if i % 2:
            continue
        for sy in (-1, 1):
            b.box((0.1, 0.1, 1.05), (x, sy * (w / 2 - 0.05), z + 1.0), m=1, col=IRON, bevel=0.01)
    for sx in (-1, 1):
        b.box((0.8, w + 0.2, 0.5), (sx * (span / 2 + 0.25), 0, 0.25), m=0, col="#6A5138", bevel=0.02)


def build():
    m = [_kit.mat("Bridge_Deck", rough=0.8), _kit.mat("Bridge_Rail", rough=0.5, metal=0.4)]
    return _kit.variants("bridge", m, [_stone, _timber], spacing=12.0)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits={"": (150, 4000)})
