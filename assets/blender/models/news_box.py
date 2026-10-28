"""Newspaper vending boxes: pedestal box with window and coin head (v1 single, v2 double, v3 low rack)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/news_box.glb"


def _unit(b, x, paint, h=1.12):
    dark = "#202225"
    b.box((0.16, 0.16, 0.26), (x, 0, 0.13), m=1, col=dark, bevel=0.02)                # pedestal
    b.box((0.44, 0.38, 0.05), (x, 0, 0.28), m=1, col=dark, bevel=0.015)
    b.box((0.44, 0.38, h - 0.3), (x, 0, 0.3 + (h - 0.3) / 2), m=0, col=paint, bevel=0.025)
    b.box((0.34, 0.05, 0.3), (x, -0.19, h - 0.1), m=1, col="#15171A", bevel=0.01)     # window
    b.box((0.44, 0.4, 0.07), (x, 0, h + 0.03), m=0, col=paint, bevel=0.02, rot=(-10, 0, 0))
    b.cyl(0.045, 0.1, (x + 0.14, -0.2, h - 0.5), m=1, col="#9EA3A8", seg=10, rot=(-90, 0, 0))
    b.box((0.2, 0.04, 0.05), (x, -0.2, h - 0.32), m=1, col="#9EA3A8", bevel=0.008)    # handle


def build():
    m = [_kit.mat("Paint_News", rough=0.5), _kit.mat("Metal_News", rough=0.45, metal=0.5)]

    def v1(b):
        _unit(b, 0.0, "#C23A2B")

    def v2(b):
        _unit(b, -0.24, "#1E5C8A")
        _unit(b, 0.24, "#D8B13A")

    def v3(b):
        _unit(b, 0.0, "#3A4A52", h=0.86)

    return _kit.variants("news_box", m, [v1, v2, v3], spacing=1.6)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
