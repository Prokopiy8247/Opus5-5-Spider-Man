"""Crosswalk stripe slab, 0.6 x 3.0 m, 12 mm thick painted band sitting on the asphalt (z=0).

Variants: v1 clean stripe, v2 worn stripe with chipped edges, v3 narrow stop-bar segment.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/road/crosswalk_stripe.glb"

PAINT = "#E4E2DA"
WORN = "#BFBCB2"


def _make(w, length, worn, chips):
    def f(b):
        b.box((w, length, 0.012), (0, 0, 0.006), m=0, col=WORN if worn else PAINT, bevel=0.004)
        for i in range(chips):
            y = -length / 2 + 0.35 + i * (length - 0.7) / max(1, chips - 1)
            b.box((w * 0.5, 0.18, 0.013), (w * 0.22, y, 0.0065), m=1, col="#2E2E2C", bevel=0.003)
    return f


def build():
    m = [_kit.mat("Road_Paint", rough=0.55), _kit.mat("Asphalt_Patch", rough=0.9)]
    return _kit.variants("crosswalk_stripe", m,
                         [_make(0.6, 3.0, False, 0), _make(0.6, 3.0, True, 3),
                          _make(0.4, 3.0, False, 0)], spacing=1.2)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits={"": (10, 2000)})
