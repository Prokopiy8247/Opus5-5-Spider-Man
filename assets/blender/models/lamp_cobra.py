"""NYC cobra-head street lamp: tapered octagonal pole, base collar, curved davit arm, head with lens."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/lamp_cobra.glb"


def _make(pole_h, paint, double):
    def f(b):
        b.cyl(0.22, 0.12, (0, 0, 0), m=0, col=paint, seg=8, bevel=0.01)          # foot plate
        b.cyl(0.16, 0.9, (0, 0, 0.12), m=0, col=paint, r2=0.12, seg=8)            # base collar
        b.cyl(0.12, pole_h - 1.0, (0, 0, 1.02), m=0, col=paint, r2=0.07, seg=8)   # pole
        b.box((0.06, 0.03, 0.28), (0, 0.12, 0.5), m=0, col=paint)                 # access door
        sides = (1, -1) if double else (1,)
        for s in sides:
            pts = [(0, 0, pole_h - 0.1), (0, s * 0.6, pole_h + 0.35), (0, s * 1.6, pole_h + 0.55), (0, s * 2.3, pole_h + 0.5)]
            for p0, p1 in zip(pts, pts[1:]):
                b.pipe(p0, p1, 0.05, m=0, col=paint, r2=0.045, seg=6)
            b.box((0.36, 0.7, 0.14), (0, s * 2.55, pole_h + 0.46), m=0, col=paint, bevel=0.04)  # head shell
            b.box((0.28, 0.55, 0.04), (0, s * 2.57, pole_h + 0.37), m=1, col="#FFE3A8", bevel=0.01)  # lens
    return f


def build():
    m = [_kit.mat("Metal_Paint", rough=0.45, metal=0.6), _kit.mat("Emit_Lamp", emit=4.0)]
    return _kit.variants("lamp_cobra", m, [_make(8.5, "#3E4A3F", False), _make(9.0, "#4A4E54", False),
                                           _make(8.5, "#2F3236", True)], spacing=6.0)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
