"""Fire hydrant: barrel body, bonnet, side caps and chains (v1 NYC bronze, v2 red, v3 short stubby)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/hydrant.glb"


def _make(body, h, cap="#8A8F94"):
    def f(b):
        b.cyl(0.26, 0.07, (0, 0, 0), m=0, col=body, seg=12, bevel=0.015)              # flange
        b.cyl(0.19, 0.05, (0, 0, 0.07), m=0, col=body, seg=12)
        b.cyl(0.155, h, (0, 0, 0.12), m=0, col=body, r2=0.135, seg=14)                # barrel
        b.cyl(0.2, 0.05, (0, 0, 0.12 + h), m=0, col=body, seg=14, bevel=0.015)        # shoulder
        b.cyl(0.17, 0.1, (0, 0, 0.17 + h), m=0, col=body, r2=0.13, seg=14)            # bonnet
        b.sphere(0.075, (0, 0, 0.3 + h), m=1, col=cap, seg=10, rings=5)               # dome nut
        b.box((0.08, 0.08, 0.09), (0, 0, 0.3 + h), m=1, col=cap, bevel=0.01)          # operating nut
        for s, yy in ((1, 0.0), (-1, 0.0)):                                           # side outlets
            b.cyl(0.085, 0.14, (s * 0.13, yy, 0.12 + h * 0.55), m=0, col=body, seg=10,
                  rot=(0, 90 * s, 0))
            b.cyl(0.095, 0.04, (s * 0.26, yy, 0.12 + h * 0.55), m=1, col=cap, seg=10,
                  rot=(0, 90 * s, 0), bevel=0.01)
        b.cyl(0.11, 0.17, (0, -0.13, 0.12 + h * 0.5), m=0, col=body, seg=10, rot=(-90, 0, 0))
        b.cyl(0.12, 0.04, (0, -0.3, 0.12 + h * 0.5), m=1, col=cap, seg=10, rot=(-90, 0, 0), bevel=0.01)
    return f


def build():
    m = [_kit.mat("Hydrant", rough=0.6), _kit.mat("Cap_Metal", rough=0.4, metal=0.7)]
    return _kit.variants("hydrant", m, [_make("#B8822E", 0.48), _make("#A8231C", 0.48),
                                        _make("#2E6B4F", 0.36)], spacing=1.2)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
