"""Sidewalk phone kiosk: back panel, side wings, hood, phone unit and shelf (v1 open kiosk, v2 full booth)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/phone_booth.glb"


def _phone(b, z0, paint):
    b.box((0.26, 0.14, 0.42), (0, 0.16, z0 + 0.21), m=0, col=paint, bevel=0.02)
    b.box((0.2, 0.05, 0.1), (0, 0.08, z0 + 0.36), m=1, col="#1A1C1E", bevel=0.01)     # keypad
    b.cyl(0.035, 0.22, (-0.14, 0.14, z0 + 0.3), m=1, col="#15171A", seg=8, rot=(0, 0, 0))
    b.box((0.4, 0.22, 0.04), (0, 0.13, z0 - 0.02), m=1, col="#3A3D42", bevel=0.01)    # shelf


def _kiosk(paint, wings, full):
    def f(b):
        b.box((1.0, 0.7, 0.05), (0, 0, 0.025), m=1, col="#33363A", bevel=0.01)        # floor plate
        b.box((0.96, 0.08, 2.15), (0, 0.31, 1.12), m=0, col=paint, bevel=0.02)        # back panel
        for sx in (-1, 1):
            if wings:
                b.box((0.06, 0.62, 1.9), (sx * 0.45, 0.0, 1.0), m=0, col=paint, bevel=0.02)
            else:
                b.cyl(0.05, 2.15, (sx * 0.45, 0.28, 0.05), m=0, col=paint, seg=8)
        if full:
            b.box((0.9, 0.05, 1.5), (0, -0.28, 1.25), m=1, col="#2B4C5A", bevel=0.01)  # glass door
        b.box((1.06, 0.78, 0.1), (0, 0.02, 2.2), m=0, col=paint, bevel=0.03)           # hood
        b.box((0.9, 0.05, 0.3), (0, -0.33, 2.02), m=1, col="#C9D4DA", bevel=0.01)      # sign panel (blank)
        _phone(b, 1.0, paint)
    return f


def build():
    m = [_kit.mat("Kiosk_Paint", rough=0.45, metal=0.4), _kit.mat("Kiosk_Glass", rough=0.2)]
    return _kit.variants("phone_booth", m, [_kiosk("#1C3F5C", False, False),
                                            _kiosk("#36393D", True, True)], spacing=2.0)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
