"""Park conifer (spruce): straight trunk with root flare, whorled short branches, stacked cone-shaped foliage tiers.

Variants: v1 spruce, v2 blue-green fir, v3 young small. LOD0, _lod1 and _bb sets.
Conifers keep their needles: the 'autumn' variant is a darker winter tint instead.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/park/tree_conifer.glb"

SPECS = [
    {"leaf": "#2C4F30", "h": 9.5, "r": 0.22, "seed": 51},
    {"leaf": "#35584F", "h": 8.5, "r": 0.2, "seed": 52},    # blue-green / winter tint
    {"leaf": "#2F5A33", "h": 5.5, "r": 0.15, "seed": 53},
]


def _tiers(b, s, count, seg):
    h = s["h"]
    for i in range(count):
        t = i / (count - 1)
        z = h * (0.2 + 0.72 * t)
        r = h * (0.21 - 0.15 * t)
        b.cyl(r, h * 0.17, (0, 0, z), m=1, col=s["leaf"], r2=r * 0.25, seg=seg)


def _lod0(b, s):
    top = _kit.trunk(b, s["h"], s["r"], seg=8, flare=1.8)
    _kit.branches(b, top, 8, s["h"] * 0.13, s["r"] * 0.3, -s["h"] * 0.02, s["seed"], seg=4, start=0.25)
    _tiers(b, s, 6, 10)


def _lod1(b, s):
    _kit.trunk(b, s["h"], s["r"], seg=6, flare=1.2)
    _tiers(b, s, 3, 7)


def build():
    return _kit.tree_sets("tree_conifer", SPECS, _lod0, _lod1, bb_size=(3.8, 9.5))


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits=_kit.TREE_LIMITS)
