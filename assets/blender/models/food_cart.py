"""Street food cart: steel body, wheels, umbrella, chimney, counter (v1 hot-dog cart, v2 coffee cart)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/food_cart.glb"

STEEL = "#A8ADB2"


def _make(canopy, chimney):
    def f(b):
        w, d = 1.5, 0.82
        for sy in (-1, 1):                                                     # wheels
            b.cyl(0.19, 0.08, (-0.35, sy * (d / 2 - 0.04), 0.19), m=0, col="#23262A", seg=14,
                  rot=(90, 0, 0))
            b.cyl(0.07, 0.09, (-0.35, sy * (d / 2 - 0.04), 0.19), m=0, col=STEEL, seg=10, rot=(90, 0, 0))
        b.cyl(0.1, 0.08, (0.6, 0, 0.0), m=0, col="#23262A", seg=10)            # front caster
        b.cyl(0.04, 0.3, (0.6, 0, 0.08), m=0, col=STEEL, seg=8)
        b.box((w, d, 0.62), (0, 0, 0.68), m=0, col=STEEL, bevel=0.03)          # body
        b.box((w + 0.12, d + 0.12, 0.06), (0, 0, 1.02), m=0, col=STEEL, bevel=0.02)   # counter top
        for x in (-0.3, 0.3):                                                  # steam wells
            b.cyl(0.16, 0.05, (x, 0.12, 1.03), m=0, col="#8E9398", seg=14, bevel=0.01)
            b.cyl(0.14, 0.03, (x, 0.12, 1.06), m=0, col="#6E7378", seg=14)
        b.box((w - 0.1, 0.04, 0.3), (0, -d / 2 - 0.02, 0.72), m=0, col="#C9CDD1", bevel=0.01)
        b.box((0.5, 0.26, 0.05), (0.45, -d / 2 - 0.12, 1.0), m=0, col=STEEL, bevel=0.012)  # tray
        b.cyl(0.03, 1.1, (0, 0.2, 1.05), m=0, col=STEEL, seg=8)                # umbrella mast
        b.cyl(0.95, 0.3, (0, 0.2, 2.0), m=1, col=canopy, r2=0.06, seg=14)      # canopy cone
        b.cyl(0.97, 0.06, (0, 0.2, 1.98), m=1, col=canopy, r2=0.9, seg=14)     # canopy skirt
        if chimney:
            b.cyl(0.05, 0.75, (-0.6, 0.25, 1.05), m=0, col=STEEL, seg=8)
            b.cyl(0.08, 0.07, (-0.6, 0.25, 1.8), m=0, col=STEEL, r2=0.06, seg=8, bevel=0.01)
    return f


def build():
    m = [_kit.mat("Cart_Steel", rough=0.4, metal=0.7), _kit.mat("Cart_Canopy", rough=0.75)]
    return _kit.variants("food_cart", m, [_make("#C4A52E", True), _make("#A8352E", False)], spacing=2.6)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits={"": (150, 2600)})
