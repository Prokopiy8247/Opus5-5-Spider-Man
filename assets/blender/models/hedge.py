"""Clipped hedge segment 2 m long (v1 box hedge 1.0 m, v2 low 0.6 m, v3 tall 1.6 m with trimmed corners)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/park/hedge.glb"


def _make(h, w, leaf, seed):
    def f(b):
        b.box((2.0, w, 0.1), (0, 0, 0.05), m=0, col="#3A3024", bevel=0.02)       # soil strip
        faces = b.box((2.0, w, h), (0, 0, 0.1 + h / 2), m=1, col=leaf, bevel=0.07)
        b.jitter(faces, 0.045, seed)
        for i in range(4):                                                        # foliage lumps on top
            x = -0.75 + i * 0.5
            lf = b.blob(w * 0.42, (x, 0, 0.1 + h), m=1, col=leaf, sub=1, scale=(1.1, 1, 0.5))
            b.jitter(lf, 0.05, seed + i)
    return f


def build():
    m = [_kit.mat("Soil", rough=0.95), _kit.mat("Leaves", rough=0.7)]
    return _kit.variants("hedge", m, [_make(1.0, 0.8, "#2F5A2A", 91), _make(0.6, 0.7, "#3A6B33", 92),
                                      _make(1.6, 0.9, "#27502A", 93)], spacing=2.6)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits={"": (150, 2600)})
