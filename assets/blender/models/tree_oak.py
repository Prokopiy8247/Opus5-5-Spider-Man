"""Park oak: thick tapered trunk with root flare, 7 heavy branches, broad clustered canopy.

Variants: v1 summer, v2 autumn rust, v3 old wide specimen. Exports LOD0, _lod1 and _bb sets.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/park/tree_oak.glb"

SPECS = [
    {"leaf": "#3F6B2A", "h": 8.0, "r": 0.3, "seed": 31, "n": 7},
    {"leaf": "#B5641C", "h": 7.4, "r": 0.28, "seed": 32, "n": 7},   # autumn
    {"leaf": "#4A7A30", "h": 9.0, "r": 0.38, "seed": 33, "n": 8},
]


def _lod0(b, s):
    top = _kit.trunk(b, s["h"] * 0.62, s["r"], seg=10, flare=1.9, lean=(0.1, 0.06))
    tips = _kit.branches(b, top, s["n"], s["h"] * 0.33, s["r"] * 0.4, s["h"] * 0.2, s["seed"],
                         seg=6, start=0.5)
    centers = [t + _kit.Vector((0, 0, 0.3)) for t in tips]
    centers += [top + _kit.Vector((0, 0, s["h"] * 0.22))]
    _kit.leaf_masses(b, centers, s["h"] * 0.2, s["leaf"], s["seed"], sub=1, squash=0.82)


def _lod1(b, s):
    top = _kit.trunk(b, s["h"] * 0.62, s["r"], seg=6, flare=1.3)
    _kit.leaf_masses(b, [top + _kit.Vector((0, 0, s["h"] * 0.17))], s["h"] * 0.33, s["leaf"],
                     s["seed"], sub=0, squash=0.78)


def build():
    return _kit.tree_sets("tree_oak", SPECS, _lod0, _lod1, bb_size=(6.5, 8.0))


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits=_kit.TREE_LIMITS)
