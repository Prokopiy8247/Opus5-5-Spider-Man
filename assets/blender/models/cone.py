"""Traffic cones: v1 70 cm cone with collar bands, v2 45 cm cone, v3 cone with weighted base ring."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/cone.glb"

ORANGE = "#D4560F"


def _make(h, base, ring):
    def f(b):
        b.box((base, base, 0.035), (0, 0, 0.017), m=0, col=ORANGE, bevel=0.012)
        b.cyl(base * 0.42, 0.05, (0, 0, 0.03), m=0, col=ORANGE, r2=base * 0.36, seg=14)
        b.cyl(base * 0.34, h - 0.1, (0, 0, 0.08), m=0, col=ORANGE, r2=0.035, seg=14)
        b.cyl(0.055, 0.03, (0, 0, h - 0.02), m=0, col=ORANGE, r2=0.045, seg=12)
        z1, z2 = h * 0.52, h * 0.74
        b.cyl(base * 0.34 - (base * 0.3) * (z1 / h) + 0.004, 0.11, (0, 0, z1), m=1, col="#EDEDE6",
              r2=base * 0.34 - (base * 0.3) * ((z1 + 0.11) / h) + 0.004, seg=14)
        b.cyl(base * 0.34 - (base * 0.3) * (z2 / h) + 0.004, 0.07, (0, 0, z2), m=1, col="#EDEDE6",
              r2=base * 0.34 - (base * 0.3) * ((z2 + 0.07) / h) + 0.004, seg=14)
        if ring:
            b.cyl(base * 0.5, 0.05, (0, 0, 0.0), m=1, col="#2B2D30", r2=base * 0.5, seg=14)
    return f


def build():
    m = [_kit.mat("Cone_Plastic", rough=0.6), _kit.mat("Cone_Band", rough=0.3)]
    return _kit.variants("cone", m, [_make(0.72, 0.36, False), _make(0.46, 0.28, False),
                                     _make(0.72, 0.4, True)], spacing=0.8)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
