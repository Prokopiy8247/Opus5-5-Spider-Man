"""Park perimeter wall, 4 m segment: schist base course, coping (v1 solid, v2 with iron railing, v3 entrance pier)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/park/park_wall.glb"

STONE = "#8A857B"
IRON = "#23262A"
L = 4.0


def _courses(b, h, seed=1):
    import random
    rnd = random.Random(seed)
    z = 0.0
    while z < h - 0.08:
        ch = min(0.26, h - 0.06 - z)
        b.box((L, 0.52 - 0.04 * (z / h), ch), (0, 0, z + ch / 2), m=0, col=STONE, bevel=0.02)
        for i in range(5):                                                  # protruding stones
            x = -L / 2 + 0.4 + i * (L - 0.8) / 4 + rnd.uniform(-0.12, 0.12)
            b.box((rnd.uniform(0.3, 0.55), 0.1, ch * 0.8), (x, rnd.choice((-0.26, 0.26)),
                  z + ch / 2), m=0, col="#948F85", bevel=0.015)
        z += ch
    b.box((L, 0.62, 0.1), (0, 0, h - 0.05), m=1, col="#9E998F", bevel=0.02)   # coping


def _v1(b):
    _courses(b, 1.1, 1)


def _v2(b):
    _courses(b, 0.75, 2)
    for i in range(13):
        x = -L / 2 + 0.15 + i * (L - 0.3) / 12
        b.pipe((x, 0, 0.75), (x, 0, 1.65), 0.02, m=1, col=IRON, seg=6)
        b.cyl(0.035, 0.07, (x, 0, 1.65), m=1, col=IRON, r2=0.0, seg=6)
    for z in (0.82, 1.58):
        b.box((L - 0.1, 0.05, 0.05), (0, 0, z), m=1, col=IRON, bevel=0.008)


def _v3(b):
    _courses(b, 1.1, 3)
    for sx in (-1, 1):
        b.box((0.7, 0.7, 2.1), (sx * (L / 2 - 0.35), 0, 1.05), m=0, col=STONE, bevel=0.03)
        b.box((0.82, 0.82, 0.12), (sx * (L / 2 - 0.35), 0, 2.16), m=1, col="#9E998F", bevel=0.025)
        b.sphere(0.18, (sx * (L / 2 - 0.35), 0, 2.38), m=1, col="#9E998F", seg=12, rings=7)


def build():
    m = [_kit.mat("Wall_Stone", rough=0.85), _kit.mat("Wall_Trim", rough=0.6, metal=0.3)]
    return _kit.variants("park_wall", m, [_v1, _v2, _v3], spacing=5.0)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits={"": (150, 3000)})
