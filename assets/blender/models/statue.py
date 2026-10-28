"""Park statue: stepped stone plinth plus a bronze figure (v1 standing figure, v2 equestrian-style, v3 obelisk)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/park/statue.glb"

STONE = "#A6A096"
BRONZE = "#4A5A42"


def _plinth(b, w, h):
    b.box((w + 0.5, w + 0.5, 0.18), (0, 0, 0.09), m=0, col=STONE, bevel=0.03)
    b.box((w + 0.22, w + 0.22, 0.16), (0, 0, 0.26), m=0, col=STONE, bevel=0.025)
    b.box((w, w, h), (0, 0, 0.34 + h / 2), m=0, col=STONE, bevel=0.03)
    b.box((w + 0.18, w + 0.18, 0.12), (0, 0, 0.4 + h), m=0, col=STONE, bevel=0.025)
    b.box((w * 0.7, 0.03, 0.3), (0, -w / 2 - 0.01, 0.34 + h * 0.55), m=0, col="#8E887E", bevel=0.01)
    return 0.46 + h


def _figure(b, z0, cape=False):
    b.box((0.5, 0.36, 0.1), (0, 0, z0 + 0.05), m=1, col=BRONZE, bevel=0.02)          # base block
    b.cyl(0.11, 0.78, (-0.1, 0, z0 + 0.08), m=1, col=BRONZE, r2=0.09, seg=10)        # legs
    b.cyl(0.1, 0.72, (0.12, 0.04, z0 + 0.08), m=1, col=BRONZE, r2=0.085, seg=10)
    b.box((0.4, 0.26, 0.6), (0, 0, z0 + 1.1), m=1, col=BRONZE, bevel=0.04)           # torso
    b.cyl(0.07, 0.6, (-0.24, 0.02, z0 + 1.3), m=1, col=BRONZE, r2=0.055, seg=8, rot=(0, 25, 0))
    b.cyl(0.07, 0.62, (0.24, -0.06, z0 + 1.35), m=1, col=BRONZE, r2=0.055, seg=8, rot=(0, -40, 0))
    b.cyl(0.08, 0.12, (0, 0, z0 + 1.4), m=1, col=BRONZE, seg=8)                      # neck
    b.sphere(0.14, (0, 0, z0 + 1.62), m=1, col=BRONZE, seg=12, rings=8)               # head
    if cape:
        b.box((0.46, 0.08, 0.95), (0, 0.16, z0 + 0.95), m=1, col=BRONZE, bevel=0.03, rot=(-6, 0, 0))


def _v1(b):
    z = _plinth(b, 1.1, 1.5)
    _figure(b, z)


def _v2(b):
    z = _plinth(b, 1.5, 1.2)
    b.box((0.7, 1.9, 0.75), (0, 0, z + 0.6), m=1, col=BRONZE, bevel=0.06)             # horse body
    b.cyl(0.14, 0.75, (0, -0.7, z), m=1, col=BRONZE, r2=0.1, seg=10)
    b.cyl(0.14, 0.75, (0, 0.6, z), m=1, col=BRONZE, r2=0.1, seg=10)
    b.cyl(0.13, 0.7, (0, 0.78, z + 0.9), m=1, col=BRONZE, r2=0.1, seg=10, rot=(-40, 0, 0))
    b.box((0.26, 0.5, 0.26), (0, 1.26, z + 1.42), m=1, col=BRONZE, bevel=0.04, rot=(-20, 0, 0))
    _figure(b, z + 0.95)


def _v3(b):
    z = _plinth(b, 1.0, 0.9)
    b.cyl(0.42, 3.4, (0, 0, z), m=0, col=STONE, r2=0.26, seg=4, rot=(0, 0, 45))       # obelisk shaft
    b.cyl(0.26, 0.5, (0, 0, z + 3.4), m=0, col=STONE, r2=0.0, seg=4, rot=(0, 0, 45))  # pyramidion
    b.box((0.5, 0.03, 0.4), (0, -0.3, z + 1.2), m=1, col=BRONZE, bevel=0.01)          # plaque


def build():
    m = [_kit.mat("Statue_Stone", rough=0.8), _kit.mat("Statue_Bronze", rough=0.4, metal=0.8)]
    return _kit.variants("statue", m, [_v1, _v2, _v3], spacing=4.0)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits={"": (150, 3000)})
