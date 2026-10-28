"""Parked hatchback: short tail with a vertical rear window, 3 paint variants."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402
import _car  # noqa: E402

GLB_PATH = "res://assets/models/props/parked_car_hatch.glb"


def _make(paint):
    def f(b):
        _car.body(b, paint, length=3.9, width=1.74, wb=2.4, roof_z=1.5, hood_z=0.96,
                  cab=(-0.95, 0.5), box_tail=True, tail_z=1.32)
    return f


def build():
    return _kit.variants("parked_car_hatch", _car.mats(),
                         [_make("#2F5E46"), _make("#D8C24A"), _make("#39404A")], spacing=5.2)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits={"": (150, 2000)})
