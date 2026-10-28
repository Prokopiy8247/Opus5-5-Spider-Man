"""Bus shelter: posts, glazed back and side, cantilever roof, bench inside (v1 long, v2 short with ad panel)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/bus_shelter.glb"


def _make(length, ad_panel):
    def f(b):
        frame = "#2B2E33"
        d = 1.5
        for x in (-length / 2 + 0.1, length / 2 - 0.1, 0.0):
            b.box((0.12, 0.12, 2.5), (x, d / 2 - 0.08, 1.25), m=0, col=frame, bevel=0.015)
            b.box((0.2, 0.2, 0.04), (x, d / 2 - 0.08, 0.02), m=0, col=frame, bevel=0.01)
        b.box((0.12, 0.12, 2.5), (-length / 2 + 0.1, -d / 2 + 0.08, 1.25), m=0, col=frame, bevel=0.015)
        b.box((0.12, d, 0.1), (-length / 2 + 0.1, 0, 2.45), m=0, col=frame, bevel=0.015)
        b.box((length, 0.04, 1.9), (0, d / 2 - 0.08, 1.3), m=1, col="#AFC6CE", bevel=0.008)   # back glass
        b.box((0.04, d - 0.2, 1.9), (-length / 2 + 0.1, 0, 1.3), m=1, col="#AFC6CE", bevel=0.008)
        b.box((length + 0.3, d + 0.35, 0.12), (0, 0.02, 2.56), m=0, col=frame, bevel=0.03)    # roof slab
        b.box((length + 0.1, d + 0.15, 0.06), (0, 0.02, 2.46), m=0, col=frame, bevel=0.02)
        b.box((length - 0.5, 0.36, 0.06), (0, d / 2 - 0.3, 0.46), m=0, col=frame, bevel=0.015)  # bench
        for x in (-length / 2 + 0.5, length / 2 - 0.5):
            b.box((0.08, 0.3, 0.44), (x, d / 2 - 0.3, 0.23), m=0, col=frame, bevel=0.01)
        if ad_panel:
            b.box((0.1, d - 0.2, 1.9), (length / 2 - 0.1, 0, 1.3), m=0, col=frame, bevel=0.02)
            b.box((0.03, d - 0.4, 1.6), (length / 2 - 0.16, 0, 1.3), m=1, col="#E8E2D2", bevel=0.005)
        else:
            b.box((0.04, d - 0.2, 1.0), (length / 2 - 0.1, 0, 1.75), m=1, col="#AFC6CE", bevel=0.008)
    return f


def build():
    m = [_kit.mat("Shelter_Frame", rough=0.45, metal=0.5), _kit.mat("Shelter_Glass", rough=0.15)]
    return _kit.variants("bus_shelter", m, [_make(4.4, False), _make(3.0, True)], spacing=6.0)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
