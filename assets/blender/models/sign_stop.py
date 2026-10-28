"""Octagonal stop sign: v1 standard, v2 with all-way plate, v3 leaning weathered post."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/sign_stop.glb"

POST = "#5A5F63"
RED = "#A82A22"


def _make(h, lean, plate):
    def f(b):
        b.cyl(0.09, 0.05, (0, 0, 0), m=0, col=POST, seg=10, bevel=0.01)
        b.cyl(0.035, h, (0, 0, 0.05), m=0, col=POST, seg=8, rot=(lean, 0, 0))
        dy = -h * 0.0175 * lean / 2.0
        b.cyl(0.42, 0.03, (0, dy, h - 0.1), m=1, col=RED, seg=8, rot=(90 + lean, 0, 0), bevel=0.01)
        b.cyl(0.36, 0.012, (0, dy - 0.02, h - 0.1), m=1, col="#F0EFEA", seg=8, rot=(90 + lean, 0, 0))
        b.cyl(0.33, 0.012, (0, dy - 0.028, h - 0.1), m=1, col=RED, seg=8, rot=(90 + lean, 0, 0))
        if plate:
            b.box((0.44, 0.02, 0.17), (0, dy, h - 0.62), m=1, col=RED, bevel=0.008)
            b.box((0.38, 0.012, 0.05), (0, dy - 0.016, h - 0.62), m=1, col="#F0EFEA", bevel=0.004)
    return f


def build():
    m = [_kit.mat("Sign_Post", rough=0.5, metal=0.5), _kit.mat("Sign_Face", rough=0.35)]
    return _kit.variants("sign_stop", m, [_make(2.4, 0, False), _make(2.4, 0, True),
                                          _make(2.2, 6, False)], spacing=1.6)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
