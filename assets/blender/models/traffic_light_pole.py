"""Side-street corner signal pole: short pole, one or two 3-lens heads, walk/don't-walk pedestrian box."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/traffic_light_pole.glb"


def _head(b, x, y, z, body, rot):
    b.box((0.34, 0.28, 0.95), (x, y, z), m=0, col=body, bevel=0.03, rot=(0, 0, rot))
    for i, c in enumerate(("#FF2A1A", "#FFB000", "#22E070")):
        lz = z + 0.29 - i * 0.29
        b.cyl(0.1, 0.03, (x, y - 0.14, lz), m=1, col=c, rot=(90, 0, 0), seg=10)
        b.box((0.24, 0.14, 0.03), (x, y - 0.2, lz + 0.12), m=0, col=body, bevel=0.005)


def _make(two, body):
    def f(b):
        b.cyl(0.24, 0.2, (0, 0, 0), m=0, col=body, seg=8, bevel=0.02)
        b.cyl(0.1, 3.6, (0, 0, 0.2), m=0, col=body, r2=0.08, seg=10)
        b.cyl(0.11, 0.06, (0, 0, 3.8), m=0, col=body, seg=10)
        _head(b, 0.0, -0.1, 3.3, body, 0)
        if two:
            _head(b, 0.25, 0.1, 2.3, body, 90)
        b.box((0.32, 0.22, 0.32), (0, -0.18, 2.4 if not two else 1.6), m=0, col=body, bevel=0.02)  # ped signal
        b.box((0.24, 0.02, 0.24), (0, -0.3, 2.4 if not two else 1.6), m=1, col="#FF7A1A", bevel=0.0)
    return f


def build():
    m = [_kit.mat("Signal_Body", rough=0.55, metal=0.3), _kit.mat("Emit_Signal", emit=5.0)]
    return _kit.variants("traffic_light_pole", m, [_make(False, "#2B2B26"), _make(True, "#3B3A1C")])


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
