"""Parked delivery van: tall box body, short bonnet, roof vent, rear doors (v1 white, v2 brown, v3 blue)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402
import _car  # noqa: E402

GLB_PATH = "res://assets/models/props/parked_car_van.glb"


def _make(paint, vent):
    def f(b):
        length, width = 5.2, 1.98
        hw = width / 2
        b.box((width, length, 0.26), (0, 0, 0.46), m=0, col=paint, bevel=0.05)             # chassis
        b.box((width, length * 0.3, 0.72), (0, length * 0.33, 0.95), m=0, col=paint, bevel=0.05)
        b.box((width, length * 0.72, 1.62), (0, -length * 0.12, 1.4), m=0, col=paint, bevel=0.06)
        b.box((width - 0.12, length * 0.74, 0.06), (0, -length * 0.12, 2.2), m=0, col=paint, bevel=0.03)
        b.box((width - 0.14, 0.05, 0.6), (0, length * 0.46, 1.5), m=1, col=_car.GLASS,
              bevel=0.012, rot=(18, 0, 0))                                                 # windscreen
        for sx in (-1, 1):
            b.box((0.04, 0.8, 0.5), (sx * (hw - 0.05), length * 0.22, 1.56), m=1, col=_car.GLASS,
                  bevel=0.01)                                                              # door glass
            b.box((0.1, 0.16, 0.12), (sx * (hw + 0.04), length * 0.42, 1.62), m=0, col=paint, bevel=0.02)
            b.box((0.06, 0.26, 0.14), (sx * (hw - 0.02), length * 0.49, 0.72), m=1, col=_car.LIGHT,
                  bevel=0.015)                                                             # headlight
            b.box((0.06, 0.08, 0.3), (sx * (hw - 0.02), -length * 0.49, 0.95), m=1, col="#8E2A22",
                  bevel=0.012)                                                             # tail light
            b.box((0.05, length * 0.68, 0.05), (sx * (hw - 0.02), -length * 0.12, 1.0), m=0,
                  col="#3A3D40", bevel=0.01)                                               # side rub strip
        b.box((width - 0.1, 0.06, 1.3), (0, -length * 0.49, 1.45), m=0, col=paint, bevel=0.02)
        b.pipe((-0.02, -length * 0.5, 1.45), (-0.02, -length * 0.5, 2.0), 0.03, m=0, col="#3A3D40", seg=6)
        b.box((width + 0.04, 0.18, 0.22), (0, length * 0.49, 0.5), m=0, col="#3A3D40", bevel=0.03)
        b.box((width + 0.04, 0.18, 0.22), (0, -length * 0.49, 0.5), m=0, col="#3A3D40", bevel=0.03)
        if vent:
            b.box((0.7, 0.7, 0.1), (0, -length * 0.2, 2.26), m=0, col="#C9CDD1", bevel=0.02)
        _car.wheels(b, 3.2, hw - 0.02, r=0.36)
    return f


def build():
    return _kit.variants("parked_car_van", _car.mats(),
                         [_make("#DCDCD4", True), _make("#5A3A24", False), _make("#24456E", True)],
                         spacing=6.6)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits={"": (150, 2000)})
