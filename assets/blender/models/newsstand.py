"""Corner newsstand kiosk: panelled box, open serving window with awning, magazine racks, roof sign (blank)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/newsstand.glb"


def _make(w, paint, awning):
    def f(b):
        d, h = 1.7, 2.5
        trim = "#2A2D31"
        b.box((w + 0.1, d + 0.1, 0.08), (0, 0, 0.04), m=0, col=trim, bevel=0.02)         # plinth
        b.box((w, d, h), (0, 0, 0.08 + h / 2), m=0, col=paint, bevel=0.03)               # body
        b.box((w - 0.5, 0.06, 1.0), (0, -d / 2 - 0.01, 1.45), m=1, col="#15171A", bevel=0.01)  # window void
        b.box((w - 0.4, 0.07, 0.08), (0, -d / 2 - 0.04, 0.95), m=0, col=trim, bevel=0.012)      # counter
        for i in range(3):                                                               # magazine shelves
            b.box((w - 0.6, 0.22, 0.04), (0, -d / 2 - 0.16, 0.5 + i * 0.22), m=0, col=trim,
                  bevel=0.008, rot=(-14, 0, 0))
        for sx in (-1, 1):                                                               # corner posts
            b.box((0.1, 0.1, h), (sx * (w / 2 - 0.04), -d / 2 + 0.04, 0.08 + h / 2), m=0, col=trim,
                  bevel=0.012)
        b.box((w + 0.3, d + 0.3, 0.12), (0, 0, h + 0.14), m=0, col=trim, bevel=0.03)     # roof
        b.box((w - 0.2, 0.08, 0.4), (0, -d / 2 - 0.08, h + 0.4), m=1, col="#E3DCCB", bevel=0.01)
        if awning:
            b.box((w + 0.2, 0.9, 0.05), (0, -d / 2 - 0.42, h - 0.1), m=1, col="#2E5C86",
                  bevel=0.01, rot=(18, 0, 0))
            for sx in (-1, 1):
                b.pipe((sx * (w / 2 - 0.05), -d / 2, h + 0.05),
                       (sx * (w / 2 - 0.05), -d / 2 - 0.85, h - 0.28), 0.025, m=0, col=trim, seg=6)
    return f


def build():
    m = [_kit.mat("Stand_Paint", rough=0.55, metal=0.2), _kit.mat("Stand_Panel", rough=0.4)]
    return _kit.variants("newsstand", m, [_make(2.6, "#2C4A3A", True), _make(2.0, "#4A3A2C", False)],
                         spacing=4.0)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits={"": (150, 2600)})
