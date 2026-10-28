"""Picnic table: plank top, A-frame legs, attached benches (v1 timber 1.8 m, v2 long 2.4 m, v3 round pedestal)."""
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/park/picnic_table.glb"

IRON = "#2C3034"


def _frame(length, wood):
    def f(b):
        top_z, seat_z = 0.75, 0.45
        for i in range(5):                                                    # table planks
            y = -0.3 + i * 0.15
            b.box((length, 0.14, 0.04), (0, y, top_z), m=0, col=wood, bevel=0.008)
        for sx in (-1, 1):
            x = sx * (length / 2 - 0.25)
            b.box((0.07, 1.5, 0.07), (x, 0, seat_z - 0.02), m=1, col=IRON, bevel=0.01)
            b.pipe((x, -0.72, 0), (x, -0.3, top_z - 0.04), 0.035, m=1, col=IRON, seg=8)
            b.pipe((x, 0.72, 0), (x, 0.3, top_z - 0.04), 0.035, m=1, col=IRON, seg=8)
            b.box((0.1, 0.1, 0.03), (x, -0.72, 0.015), m=1, col=IRON, bevel=0.006)
            b.box((0.1, 0.1, 0.03), (x, 0.72, 0.015), m=1, col=IRON, bevel=0.006)
        for sy in (-1, 1):                                                    # benches
            for i in range(2):
                b.box((length, 0.14, 0.04), (0, sy * (0.62 + i * 0.16), seat_z), m=0, col=wood,
                      bevel=0.008)
    return f


def _round_table(b):
    wood = "#6B4A2E"
    b.cyl(0.2, 0.06, (0, 0, 0), m=1, col=IRON, seg=14, bevel=0.012)
    b.cyl(0.08, 0.7, (0, 0, 0.06), m=1, col=IRON, seg=12)
    b.cyl(0.85, 0.05, (0, 0, 0.74), m=0, col=wood, seg=18, bevel=0.012)
    for i in range(8):
        a = i / 8 * math.tau
        b.box((0.6, 0.1, 0.055), (math.cos(a) * 0.4, math.sin(a) * 0.4, 0.73), m=0, col=wood,
              bevel=0.006, rot=(0, 0, math.degrees(a)))
    for i in range(4):
        a = i / 4 * math.tau + math.pi / 4
        cx, cy = math.cos(a) * 1.25, math.sin(a) * 1.25
        b.cyl(0.26, 0.05, (cx, cy, 0.45), m=0, col=wood, seg=12, bevel=0.01)
        b.cyl(0.05, 0.45, (cx, cy, 0.0), m=1, col=IRON, seg=10)
        b.cyl(0.14, 0.03, (cx, cy, 0.0), m=1, col=IRON, seg=10)


def build():
    m = [_kit.mat("Table_Wood", rough=0.8), _kit.mat("Table_Steel", rough=0.45, metal=0.6)]
    return _kit.variants("picnic_table", m, [_frame(1.8, "#7A5434"), _frame(2.4, "#5E4028"),
                                             _round_table], spacing=3.4)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits={"": (150, 2600)})
