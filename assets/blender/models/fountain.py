"""Park fountain: stepped stone basin, pedestal, upper bowl, water surface disc (v1 round, v2 octagonal tiered)."""
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/park/fountain.glb"

STONE = "#AFA89B"
WATER = "#3C6E86"


def _round(b):
    b.cyl(3.2, 0.12, (0, 0, 0), m=0, col=STONE, seg=24, bevel=0.03)             # plinth
    b.cyl(3.0, 0.62, (0, 0, 0.12), m=0, col=STONE, seg=24, bevel=0.03)          # basin wall outer
    b.cyl(2.72, 0.6, (0, 0, 0.14), m=0, col="#9D968A", seg=24)                   # basin inner
    b.cyl(3.08, 0.12, (0, 0, 0.7), m=0, col=STONE, seg=24, bevel=0.03)           # coping
    b.cyl(2.74, 0.02, (0, 0, 0.52), m=1, col=WATER, seg=24)                      # water surface
    b.cyl(0.65, 0.5, (0, 0, 0.14), m=0, col=STONE, r2=0.42, seg=16, bevel=0.02)  # pedestal
    b.cyl(0.2, 0.9, (0, 0, 0.6), m=0, col=STONE, r2=0.16, seg=12)
    b.cyl(1.1, 0.14, (0, 0, 1.4), m=0, col=STONE, r2=1.0, seg=20, bevel=0.025)   # upper bowl
    b.cyl(0.98, 0.1, (0, 0, 1.46), m=1, col=WATER, seg=20)
    b.cyl(0.1, 0.5, (0, 0, 1.54), m=0, col=STONE, r2=0.06, seg=10)
    b.cyl(0.05, 0.6, (0, 0, 2.0), m=1, col=WATER, r2=0.02, seg=8)                # jet
    for i in range(8):
        a = i / 8 * math.tau
        b.box((0.24, 0.1, 0.1), (math.cos(a) * 2.9, math.sin(a) * 2.9, 0.78), m=0, col=STONE,
              bevel=0.015, rot=(0, 0, math.degrees(a)))


def _octo(b):
    b.cyl(2.9, 0.15, (0, 0, 0), m=0, col=STONE, seg=8, bevel=0.03)
    b.cyl(2.7, 0.55, (0, 0, 0.15), m=0, col=STONE, seg=8, bevel=0.03)
    b.cyl(2.45, 0.55, (0, 0, 0.17), m=0, col="#9D968A", seg=8)
    b.cyl(2.78, 0.1, (0, 0, 0.7), m=0, col=STONE, seg=8, bevel=0.025)
    b.cyl(2.47, 0.02, (0, 0, 0.5), m=1, col=WATER, seg=8)
    for i, (r, z) in enumerate(((1.5, 0.15), (1.0, 0.95), (0.6, 1.55))):
        b.cyl(r, 0.14, (0, 0, z), m=0, col=STONE, r2=r * 0.92, seg=8, bevel=0.02)
        b.cyl(r * 0.86, 0.05, (0, 0, z + 0.1), m=1, col=WATER, seg=8)
        b.cyl(r * 0.3, max(0.3, 0.8 - i * 0.2), (0, 0, z + 0.14), m=0, col=STONE, r2=r * 0.22, seg=10)
    b.cyl(0.05, 0.5, (0, 0, 2.0), m=1, col=WATER, r2=0.02, seg=8)


def build():
    m = [_kit.mat("Fountain_Stone", rough=0.8), _kit.mat("Fountain_Water", rough=0.1)]
    return _kit.variants("fountain", m, [_round, _octo], spacing=8.0)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits={"": (150, 3500)})
