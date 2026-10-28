"""Park schist outcrop rocks (v1 boulder 1.6 m, v2 flat slab, v3 small cluster of three)."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/park/rock.glb"

STONE = "#7C7A74"
MOSS = "#4A6038"


def _boulder(b, r, loc, seed, scale, moss=True):
    f = b.blob(r, loc, m=0, col=STONE, sub=2, scale=scale, rot=(0, 0, seed * 13 % 90), smooth=False)
    b.jitter(f, r * 0.2, seed)
    if moss:
        mf = b.blob(r * 0.6, (loc[0], loc[1], loc[2] + r * scale[2] * 0.55), m=1, col=MOSS, sub=1,
                    scale=(1.1, 1.1, 0.3))
        b.jitter(mf, r * 0.1, seed + 7)


def _v1(b):
    _boulder(b, 0.9, (0, 0, 0.55), 101, (1.1, 0.9, 0.8))


def _v2(b):
    _boulder(b, 1.1, (0, 0, 0.22), 102, (1.2, 1.0, 0.28), moss=False)
    _boulder(b, 0.35, (0.9, 0.3, 0.2), 103, (1.0, 1.0, 0.7))


def _v3(b):
    _boulder(b, 0.5, (0, 0, 0.32), 104, (1.0, 0.9, 0.8))
    _boulder(b, 0.34, (0.75, -0.2, 0.22), 105, (1.1, 1.0, 0.75), moss=False)
    _boulder(b, 0.26, (-0.55, 0.4, 0.16), 106, (1.0, 1.1, 0.7))


def build():
    m = [_kit.mat("Rock", rough=0.9), _kit.mat("Moss", rough=0.8)]
    return _kit.variants("rock", m, [_v1, _v2, _v3], spacing=3.0)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits={"": (150, 2600)})
