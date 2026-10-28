"""Orange-and-white steam stack over a manhole (Con-Ed style): v1 tall stack, v2 short stack, v3 stack + cones."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/steam_stack.glb"

ORANGE = "#D4560F"
WHITE = "#EDEBE2"


def _make(h, bands, skirt_cones):
    def f(b):
        b.cyl(0.46, 0.06, (0, 0, 0), m=0, col=ORANGE, seg=16, bevel=0.012)            # base skirt
        b.cyl(0.4, 0.1, (0, 0, 0.06), m=0, col=ORANGE, r2=0.34, seg=16)
        b.cyl(0.3, h, (0, 0, 0.16), m=0, col=ORANGE, r2=0.26, seg=16)                 # stack body
        for i in range(bands):
            z = 0.4 + i * (h - 0.6) / max(1, bands - 1)
            b.cyl(0.305 - 0.04 * (z / h), 0.22, (0, 0, z), m=1, col=WHITE,
                  r2=0.3 - 0.04 * ((z + 0.22) / h), seg=16)
        b.cyl(0.3, 0.07, (0, 0, 0.16 + h), m=0, col=ORANGE, r2=0.33, seg=16, bevel=0.012)
        b.cyl(0.27, 0.05, (0, 0, 0.1), m=1, col="#2A2C2E", seg=16)                     # inner lip
        if skirt_cones:
            for sx, sy in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
                b.cyl(0.14, 0.42, (sx * 0.75, sy * 0.75, 0), m=0, col=ORANGE, r2=0.03, seg=10)
                b.box((0.3, 0.3, 0.03), (sx * 0.75, sy * 0.75, 0.015), m=0, col=ORANGE, bevel=0.008)
                b.cyl(0.1, 0.07, (sx * 0.75, sy * 0.75, 0.2), m=1, col=WHITE, r2=0.085, seg=10)
    return f


def build():
    m = [_kit.mat("Stack_Paint", rough=0.6), _kit.mat("Stack_Band", rough=0.5)]
    return _kit.variants("steam_stack", m, [_make(2.4, 3, False), _make(1.4, 2, False),
                                            _make(2.4, 3, True)], spacing=2.4)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
