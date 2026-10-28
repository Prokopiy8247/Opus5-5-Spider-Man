"""Sidewalk scaffold shed (NYC construction bridge): pipe frame, plank deck, lamp strip under the deck."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/scaffold_shed.glb"

PIPE = "#7E8286"


def _make(length, paint, railing):
    def f(b):
        d, h = 2.6, 3.4
        xs = [-length / 2 + 0.25, 0.0, length / 2 - 0.25]
        for x in xs:
            for sy in (-1, 1):
                b.pipe((x, sy * (d / 2 - 0.2), 0), (x, sy * (d / 2 - 0.2), h), 0.05, m=0, col=PIPE, seg=8)
                b.box((0.18, 0.18, 0.04), (x, sy * (d / 2 - 0.2), 0.02), m=0, col=PIPE, bevel=0.008)
            b.pipe((x, -(d / 2 - 0.2), h - 0.1), (x, d / 2 - 0.2, h - 0.1), 0.045, m=0, col=PIPE, seg=8)
            b.pipe((x, -(d / 2 - 0.2), 1.1), (x, d / 2 - 0.2, 1.1), 0.035, m=0, col=PIPE, seg=6)
        for sy in (-1, 1):
            for z in (1.1, 2.3, h - 0.1):
                b.pipe((xs[0], sy * (d / 2 - 0.2), z), (xs[-1], sy * (d / 2 - 0.2), z), 0.04,
                       m=0, col=PIPE, seg=8)
        for i in range(5):                                                      # deck planks
            y = -d / 2 + 0.3 + i * (d - 0.6) / 4
            b.box((length, (d - 0.6) / 4 - 0.02, 0.05), (0, y, h + 0.03), m=1, col=paint, bevel=0.008)
        b.box((length, 0.16, 0.5), (0, -d / 2 + 0.1, h + 0.3), m=1, col=paint, bevel=0.015)  # fascia
        b.box((length - 0.3, 0.1, 0.06), (0, -d / 2 + 0.22, h - 0.25), m=0, col="#FFEEBB", bevel=0.01)
        if railing:
            for sy in (-1, 1):
                b.pipe((xs[0], sy * (d / 2 - 0.1), h + 1.0), (xs[-1], sy * (d / 2 - 0.1), h + 1.0),
                       0.035, m=0, col=PIPE, seg=6)
                for x in xs:
                    b.pipe((x, sy * (d / 2 - 0.1), h), (x, sy * (d / 2 - 0.1), h + 1.0), 0.035,
                           m=0, col=PIPE, seg=6)
    return f


def build():
    m = [_kit.mat("Scaffold_Pipe", rough=0.45, metal=0.7), _kit.mat("Emit_Shed_Deck", emit=1.2)]
    return _kit.variants("scaffold_shed", m, [_make(8.0, "#2E6B4A", True),
                                              _make(6.0, "#1F4F7A", False)], spacing=10.0)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits={"": (150, 4500)})
