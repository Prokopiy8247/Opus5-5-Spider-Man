"""Park blossom tree (cherry): short leaning trunk, spreading branches, pink flower clusters.

Variants: v1 pink bloom, v2 white bloom, v3 autumn bare-ish copper. LOD0, _lod1 and _bb sets.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/park/tree_blossom.glb"

SPECS = [
    {"leaf": "#E4A7C0", "h": 5.4, "r": 0.17, "seed": 61},
    {"leaf": "#F0E6E2", "h": 5.0, "r": 0.16, "seed": 62},
    {"leaf": "#C47A3A", "h": 5.2, "r": 0.17, "seed": 63},   # autumn
]


def _lod0(b, s):
    top = _kit.trunk(b, s["h"] * 0.5, s["r"], bark="#4A3A30", seg=8, flare=1.8, lean=(0.25, -0.15))
    tips = _kit.branches(b, top, 8, s["h"] * 0.38, s["r"] * 0.38, s["h"] * 0.2, s["seed"], seg=5,
                         start=0.45, bark="#4A3A30")
    centers = []
    for t in tips:
        centers.append(t + _kit.Vector((0, 0, 0.18)))
        centers.append(t * 0.8 + _kit.Vector((0, 0, 0.5)))
    _kit.leaf_masses(b, centers, s["h"] * 0.15, s["leaf"], s["seed"], sub=1, squash=0.7)


def _lod1(b, s):
    top = _kit.trunk(b, s["h"] * 0.5, s["r"], bark="#4A3A30", seg=6, flare=1.2)
    _kit.leaf_masses(b, [top + _kit.Vector((0, 0, s["h"] * 0.2))], s["h"] * 0.3, s["leaf"],
                     s["seed"], sub=0, squash=0.62)


def build():
    return _kit.tree_sets("tree_blossom", SPECS, _lod0, _lod1, bb_size=(5.0, 5.4))


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits=_kit.TREE_LIMITS)
