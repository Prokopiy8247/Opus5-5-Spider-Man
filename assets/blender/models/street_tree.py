"""Street tree (sidewalk pit tree): slim tapered trunk with root flare, high branches, clustered canopy.

Variants: v1 summer honeylocust, v2 autumn, v3 young narrow tree. Also _lod1 and _bb sets.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/street_tree.glb"

SPECS = [
    {"leaf": "#4C7A33", "h": 6.2, "r": 0.13, "seed": 11},
    {"leaf": "#C07A1E", "h": 5.8, "r": 0.12, "seed": 12},   # autumn
    {"leaf": "#5E8A3C", "h": 4.6, "r": 0.09, "seed": 13},
]


def _lod0(b, s):
    top = _kit.trunk(b, s["h"], s["r"], seg=8, lean=(0.08, -0.05))
    tips = _kit.branches(b, top, 6, s["h"] * 0.3, s["r"] * 0.42, s["h"] * 0.22, s["seed"], seg=5, start=0.6)
    centers = [t + _kit.Vector((0, 0, 0.25)) for t in tips] + [top + _kit.Vector((0, 0, 0.5))]
    _kit.leaf_masses(b, centers, s["h"] * 0.17, s["leaf"], s["seed"], sub=1, squash=0.78)


def _lod1(b, s):
    top = _kit.trunk(b, s["h"], s["r"], seg=6, flare=1.3)
    _kit.leaf_masses(b, [top + _kit.Vector((0, 0, s["h"] * 0.16))], s["h"] * 0.26, s["leaf"],
                     s["seed"], sub=0, squash=0.7)


def build():
    return _kit.tree_sets("street_tree", SPECS, _lod0, _lod1, bb_size=(3.4, 6.2))


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits=_kit.TREE_LIMITS)
