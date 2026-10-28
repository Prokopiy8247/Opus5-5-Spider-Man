"""City / park bench: cast-iron end frames, slatted seat and back, armrests (v2 backless, v3 long)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/bench.glb"


def _make(length, wood, back):
    def f(b):
        iron = "#22262A"
        for x in (-length / 2 + 0.12, length / 2 - 0.12):
            b.box((0.06, 0.5, 0.06), (x, 0, 0.42), m=1, col=iron)                    # seat support
            b.pipe((x, -0.22, 0), (x, -0.2, 0.42), 0.03, m=1, col=iron, seg=6)       # front leg
            b.pipe((x, 0.22, 0), (x, 0.26, 0.42), 0.03, m=1, col=iron, seg=6)        # back leg
            b.box((0.05, 0.42, 0.04), (x, 0.0, 0.66), m=1, col=iron)                 # armrest
            if back:
                b.pipe((x, 0.26, 0.42), (x, 0.36, 0.9), 0.03, m=1, col=iron, seg=6)
        for i in range(4):
            b.box((length, 0.1, 0.035), (0, -0.18 + i * 0.12, 0.46), m=0, col=wood, bevel=0.008)
        if back:
            for i in range(3):
                z = 0.58 + i * 0.12
                b.box((length, 0.035, 0.09), (0, 0.29 + i * 0.022, z), m=0, col=wood, bevel=0.008, rot=(-12, 0, 0))
    return f


def build():
    m = [_kit.mat("Wood", rough=0.8), _kit.mat("Iron", rough=0.5, metal=0.6)]
    return _kit.variants("bench", m, [_make(1.8, "#7A5434", True), _make(1.8, "#3E5F3A", False),
                                      _make(2.4, "#5E3E26", True)])


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
