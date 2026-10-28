"""Park / historic district post-top lantern: fluted cast base, slim post, glass lantern with cap and finial."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/lamp_lantern.glb"


def _make(h, paint, twin):
    def f(b):
        b.cyl(0.26, 0.1, (0, 0, 0), m=0, col=paint, seg=10, bevel=0.01)
        b.cyl(0.2, 0.7, (0, 0, 0.1), m=0, col=paint, r2=0.1, seg=10)
        b.cyl(0.12, 0.08, (0, 0, 0.8), m=0, col=paint, seg=10)
        b.cyl(0.07, h - 1.6, (0, 0, 0.88), m=0, col=paint, r2=0.055, seg=10)
        heads = [(0.55, 0), (-0.55, 0)] if twin else [(0, 0)]
        top = h - 0.72
        if twin:
            b.pipe((-0.6, 0, top - 0.05), (0.6, 0, top - 0.05), 0.04, m=0, col=paint, seg=6)
        for x, y in heads:
            b.cyl(0.1, 0.08, (x, y, top), m=0, col=paint, r2=0.16, seg=6)
            b.cyl(0.15, 0.42, (x, y, top + 0.08), m=1, col="#FFDDA0", r2=0.19, seg=6)    # glass
            b.cyl(0.24, 0.12, (x, y, top + 0.5), m=0, col=paint, r2=0.05, seg=6)         # cap
            b.cyl(0.03, 0.12, (x, y, top + 0.62), m=0, col=paint, r2=0.0, seg=6)         # finial
    return f


def build():
    m = [_kit.mat("Cast_Iron", rough=0.5, metal=0.5), _kit.mat("Emit_Lantern", emit=3.5)]
    return _kit.variants("lamp_lantern", m, [_make(4.2, "#1E2A22", False), _make(4.4, "#222226", True)])


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
