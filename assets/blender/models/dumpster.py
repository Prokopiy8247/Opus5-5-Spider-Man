"""Steel dumpster: tapered tub, ribs, lift pockets, lids (v1 closed, v2 one lid open, v3 small)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/dumpster.glb"


def _make(w, d, h, paint, open_lid=False):
    def f(b):
        trim = "#2A2C30"
        b.box((w, d, h), (0, 0, 0.14 + h / 2), m=0, col=paint, bevel=0.03, rot=(0, 0, 0))
        b.box((w - 0.08, d - 0.3, h * 0.55), (0, 0, 0.14 + h * 0.28), m=0, col=paint, bevel=0.02)
        for i in range(4):                                                             # vertical ribs
            x = -w / 2 + 0.2 + i * (w - 0.4) / 3
            b.box((0.06, d + 0.03, h - 0.1), (x, 0, 0.14 + h / 2), m=0, col=paint, bevel=0.012)
        b.box((w + 0.04, d + 0.04, 0.07), (0, 0, 0.11 + h), m=1, col=trim, bevel=0.015)  # top rail
        for sx in (-1, 1):                                                             # lift pockets
            b.box((0.18, d * 0.5, 0.16), (sx * (w / 2 - 0.22), 0, 0.3), m=1, col=trim, bevel=0.01)
            for sy in (-1, 1):                                                         # casters
                b.cyl(0.07, 0.05, (sx * (w / 2 - 0.16), sy * (d / 2 - 0.14), 0.0), m=1,
                      col=trim, seg=10, rot=(0, 90, 0))
                b.box((0.05, 0.05, 0.1), (sx * (w / 2 - 0.16), sy * (d / 2 - 0.14), 0.09), m=1, col=trim)
        lid_z = 0.17 + h
        for sy, ang in ((-1, 0), (1, 0)):
            if open_lid and sy > 0:
                b.box((w - 0.06, d / 2 - 0.03, 0.05), (0, d / 2 - 0.05, lid_z + (d / 4)), m=0,
                      col=paint, bevel=0.015, rot=(-78, 0, 0))
            else:
                b.box((w - 0.06, d / 2 - 0.03, 0.05), (0, sy * (d / 4), lid_z), m=0, col=paint,
                      bevel=0.015, rot=(ang, 0, 0))
    return f


def build():
    m = [_kit.mat("Paint_Steel", rough=0.6, metal=0.3), _kit.mat("Trim_Steel", rough=0.45, metal=0.7)]
    return _kit.variants("dumpster", m, [_make(1.9, 1.3, 1.15, "#2F5C41"),
                                         _make(1.9, 1.3, 1.15, "#3B4450", True),
                                         _make(1.4, 1.1, 0.95, "#6A4030")], spacing=2.6)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
