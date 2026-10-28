"""Curb ramp (ADA): sloped concrete pan from sidewalk top 0.15 down to road 0, flared sides, tactile dome panel.

Variants: v1 perpendicular ramp, v2 wide diagonal corner ramp.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/road/curb_ramp.glb"

CONC = "#B4B1A8"
TACT = "#A3542C"


def _make(width, flares):
    def f(b):
        run = 1.5
        # Sloped pan: box rotated so the street edge sits at z=0 and the back at z=0.15.
        b.box((width, run, 0.1), (0, run / 2, 0.075), m=0, col=CONC, bevel=0.01,
              rot=(-5.7, 0, 0))
        b.box((width, 0.3, 0.16), (0, run + 0.15, 0.08), m=0, col=CONC, bevel=0.012)   # landing
        b.box((width, 0.16, 0.05), (0, 0.08, 0.025), m=0, col=CONC, bevel=0.008)       # gutter lip
        b.box((width - 0.2, 0.6, 0.03), (0, 0.45, 0.06), m=1, col=TACT, bevel=0.006)   # tactile panel
        for s in range(flares):
            sx = 1 if s == 0 else -1
            b.box((0.7, run, 0.16), (sx * (width / 2 + 0.33), run / 2, 0.08), m=0, col=CONC,
                  bevel=0.012, rot=(0, -13 * sx, 0))
    return f


def build():
    m = [_kit.mat("Concrete", rough=0.85), _kit.mat("Tactile", rough=0.6)]
    return _kit.variants("curb_ramp", m, [_make(1.6, 2), _make(2.4, 2)], spacing=4.0)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
