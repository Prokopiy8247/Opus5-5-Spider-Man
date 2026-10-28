"""Park shrub: woody stems plus clustered leaf blobs (v1 green round, v2 autumn, v3 flowering low)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/park/shrub.glb"


def _make(leaf, h, r, seed, flowers=None):
    def f(b):
        import math
        import random
        rnd = random.Random(seed)
        b.cyl(r * 0.3, 0.12, (0, 0, 0), m=0, col="#4A3A2C", r2=r * 0.16, seg=8)
        centers = []
        for i in range(5):
            a = i / 5 * math.tau + rnd.uniform(-0.3, 0.3)
            tip = (math.cos(a) * r * 0.55, math.sin(a) * r * 0.55, h * rnd.uniform(0.55, 0.85))
            b.pipe((0, 0, 0.08), tip, r * 0.07, m=0, col="#4A3A2C", r2=r * 0.03, seg=5)
            centers.append(_kit.Vector(tip) + _kit.Vector((0, 0, h * 0.12)))
        centers.append(_kit.Vector((0, 0, h * 0.72)))
        _kit.leaf_masses(b, centers, r * 0.52, leaf, seed, sub=1, squash=0.85)
        if flowers:
            for i in range(6):
                a = i / 6 * 6.2832
                b.blob(r * 0.12, (math.cos(a) * r * 0.5, math.sin(a) * r * 0.5, h * 0.8), m=1,
                       col=flowers, sub=0)
    return f


def build():
    m = [_kit.mat("Bark", rough=0.9), _kit.mat("Leaves", rough=0.7)]
    return _kit.variants("shrub", m, [_make("#3E6B2E", 1.3, 0.9, 81),
                                      _make("#B5721E", 1.2, 0.85, 82),
                                      _make("#4A7A33", 0.9, 1.0, 83, flowers="#E0D24A")],
                         spacing=2.4)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits={"": (150, 2600)})
