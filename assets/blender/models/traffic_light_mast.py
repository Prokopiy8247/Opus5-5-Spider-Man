"""Avenue mast-arm traffic signal: heavy pole, long horizontal mast arm with gusset, 2-3 hanging 3-lens heads."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/traffic_light_mast.glb"


def _head(b, x, z, body):
    b.box((0.36, 0.3, 1.0), (x, 0, z), m=0, col=body, bevel=0.03)
    for i, c in enumerate(("#FF2A1A", "#FFB000", "#22E070")):
        lz = z + 0.3 - i * 0.3
        b.cyl(0.11, 0.03, (x, -0.15, lz), m=1, col=c, rot=(90, 0, 0), seg=10)       # lens
        b.box((0.26, 0.16, 0.03), (x, -0.22, lz + 0.13), m=0, col=body, bevel=0.005)  # visor


def _make(arm, heads, body):
    def f(b):
        b.cyl(0.3, 0.25, (0, 0, 0), m=0, col=body, seg=8, bevel=0.02)
        b.cyl(0.16, 6.6, (0, 0, 0.25), m=0, col=body, r2=0.12, seg=10)
        b.pipe((0, 0, 6.2), (arm, 0, 6.35), 0.09, m=0, col=body, r2=0.06, seg=8)
        b.pipe((0, 0, 5.3), (1.6, 0, 6.25), 0.04, m=0, col=body, seg=6)             # gusset strut
        b.box((0.28, 0.2, 0.4), (0.0, -0.2, 2.6), m=0, col=body, bevel=0.02)          # ped button box
        for i in range(heads):
            x = arm - 0.6 - i * 2.4
            b.pipe((x, 0, 6.3), (x, 0, 5.95), 0.025, m=0, col=body, seg=6)
            _head(b, x, 5.4, body)
    return f


def build():
    m = [_kit.mat("Signal_Body", rough=0.55, metal=0.3), _kit.mat("Emit_Signal", emit=5.0)]
    return _kit.variants("traffic_light_mast", m, [_make(7.5, 3, "#2B2B26"), _make(5.5, 2, "#3B3A1C")], spacing=10.0)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
