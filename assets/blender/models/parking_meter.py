"""Parking meters: v1 single-space post meter, v2 twin head, v3 muni pay station column."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/parking_meter.glb"

BODY = "#4C5257"


def _post(b, h):
    b.cyl(0.11, 0.06, (0, 0, 0), m=0, col=BODY, seg=12, bevel=0.012)
    b.cyl(0.055, h, (0, 0, 0.06), m=0, col=BODY, seg=12)


def _head(b, x, z):
    b.box((0.17, 0.13, 0.3), (x, 0, z + 0.15), m=0, col=BODY, bevel=0.025)
    b.box((0.12, 0.03, 0.12), (x, -0.075, z + 0.21), m=1, col="#16181A", bevel=0.008)   # display
    b.cyl(0.03, 0.02, (x, -0.08, z + 0.07), m=1, col="#C7CBD0", seg=10, rot=(-90, 0, 0))  # coin slot
    b.box((0.17, 0.14, 0.05), (x, 0, z + 0.32), m=0, col=BODY, bevel=0.02, rot=(0, 0, 0))


def _v1(b):
    _post(b, 1.05)
    _head(b, 0.0, 1.05)


def _v2(b):
    _post(b, 1.05)
    b.box((0.4, 0.1, 0.06), (0, 0, 1.03), m=0, col=BODY, bevel=0.012)
    _head(b, -0.16, 1.06)
    _head(b, 0.16, 1.06)


def _v3(b):
    b.box((0.34, 0.26, 0.08), (0, 0, 0.04), m=0, col=BODY, bevel=0.02)
    b.box((0.3, 0.22, 1.25), (0, 0, 0.7), m=0, col=BODY, bevel=0.03)
    b.box((0.3, 0.24, 0.26), (0, 0, 1.44), m=0, col=BODY, bevel=0.025, rot=(-14, 0, 0))
    b.box((0.2, 0.04, 0.14), (0, -0.13, 1.46), m=1, col="#16181A", bevel=0.008)
    b.box((0.1, 0.03, 0.12), (0.08, -0.12, 1.2), m=1, col="#C7CBD0", bevel=0.006)
    b.box((0.3, 0.26, 0.05), (0, 0, 1.6), m=0, col=BODY, bevel=0.02)


def build():
    m = [_kit.mat("Meter_Body", rough=0.5, metal=0.4), _kit.mat("Meter_Face", rough=0.25)]
    return _kit.variants("parking_meter", m, [_v1, _v2, _v3], spacing=1.0)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
