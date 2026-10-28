"""Parked sedan (4-door): 3 paint variants, long hood and trunk, wheels on the ground."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402
import _car  # noqa: E402

GLB_PATH = "res://assets/models/props/parked_car_sedan.glb"


def _make(paint):
    def f(b):
        _car.body(b, paint, length=4.6, width=1.82, wb=2.7, roof_z=1.44, hood_z=0.98,
                  cab=(-0.9, 0.85))
    return f


def build():
    return _kit.variants("parked_car_sedan", _car.mats(),
                         [_make("#2E3A4E"), _make("#8E9094"), _make("#6E2A28")], spacing=6.0)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits={"": (150, 2000)})
