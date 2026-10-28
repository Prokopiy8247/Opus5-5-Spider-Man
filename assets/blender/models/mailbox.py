"""USPS-style street mailbox: rounded-top box, pull handle, legs (v1 blue, v2 relay box, v3 wide)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/mailbox.glb"


def _make(w, paint, hopper=True):
    def f(b):
        trim = "#1A1C1F"
        for sx in (-1, 1):
            for sy in (-1, 1):
                b.box((0.07, 0.07, 0.42), (sx * (w / 2 - 0.1), sy * 0.2, 0.21), m=1, col=trim)
                b.box((0.14, 0.14, 0.03), (sx * (w / 2 - 0.1), sy * 0.2, 0.015), m=1, col=trim)
        b.box((w, 0.58, 0.72), (0, 0, 0.78), m=0, col=paint, bevel=0.035)              # body
        b.cyl(w / 2 - 0.01, 0.56, (0, 0.28, 1.14), m=0, col=paint, seg=14, rot=(90, 0, 0))  # round top
        if hopper:
            b.box((w - 0.14, 0.1, 0.3), (0, -0.3, 1.0), m=0, col=paint, bevel=0.02, rot=(-18, 0, 0))
            b.cyl(0.035, w - 0.3, (-(w - 0.3) / 2, -0.37, 1.1), m=1, col=trim, seg=8, rot=(0, 90, 0))
        else:
            b.box((w - 0.2, 0.05, 0.42), (0, -0.3, 0.9), m=1, col=trim, bevel=0.02)     # relay door
            b.cyl(0.05, 0.05, (0.0, -0.33, 0.68), m=1, col=trim, seg=10, rot=(-90, 0, 0))
        b.box((w - 0.1, 0.1, 0.05), (0, 0.26, 0.5), m=1, col=trim, bevel=0.01)          # rear plate
    return f


def build():
    m = [_kit.mat("Paint_Box", rough=0.5), _kit.mat("Trim_Dark", rough=0.45, metal=0.4)]
    return _kit.variants("mailbox", m, [_make(0.66, "#1F4C8C"), _make(0.66, "#2A5B33", False),
                                        _make(0.86, "#17407A")], spacing=1.6)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
