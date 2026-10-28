"""Park poplar: tall slim trunk, short upswept branches, narrow columnar canopy.

Variants: v1 summer green, v2 autumn yellow, v3 very tall. LOD0, _lod1 and _bb sets.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/park/tree_poplar.glb"

SPECS = [
    {"leaf": "#4F7A34", "h": 11.0, "r": 0.2, "seed": 41},
    {"leaf": "#D2A519", "h": 10.0, "r": 0.19, "seed": 42},   # autumn
    {"leaf": "#436B2E", "h": 13.0, "r": 0.23, "seed": 43},
]


def _lod0(b, s):
    top = _kit.trunk(b, s["h"] * 0.9, s["r"], seg=8, flare=1.6)
    tips = _kit.branches(b, top, 7, s["h"] * 0.1, s["r"] * 0.3, s["h"] * 0.1, s["seed"], seg=5, start=0.35)
    centers = [t + _kit.Vector((0, 0, 0.2)) for t in tips] + [top + _kit.Vector((0, 0, 0.4))]
    _kit.leaf_masses(b, centers, s["h"] * 0.1, s["leaf"], s["seed"], sub=1, squash=1.25)


def _lod1(b, s):
    top = _kit.trunk(b, s["h"] * 0.9, s["r"], seg=6, flare=1.2)
    _kit.leaf_masses(b, [top + _kit.Vector((0, 0, -s["h"] * 0.2))], s["h"] * 0.18, s["leaf"],
                     s["seed"], sub=0, squash=1.9)


def build():
    return _kit.tree_sets("tree_poplar", SPECS, _lod0, _lod1, bb_size=(3.2, 11.0))


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits=_kit.TREE_LIMITS)
