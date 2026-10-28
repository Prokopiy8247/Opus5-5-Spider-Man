"""Park maple: medium tapered trunk with root flare, forked branches, rounded dense canopy.

Variants: v1 summer green, v2 autumn scarlet, v3 autumn orange. LOD0, _lod1 and _bb sets.
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/park/tree_maple.glb"

SPECS = [
    {"leaf": "#4A7A2E", "h": 7.2, "r": 0.24, "seed": 71},
    {"leaf": "#B2301F", "h": 6.8, "r": 0.23, "seed": 72},   # autumn scarlet
    {"leaf": "#D97A18", "h": 7.0, "r": 0.24, "seed": 73},   # autumn orange
]


def _lod0(b, s):
    top = _kit.trunk(b, s["h"] * 0.55, s["r"], bark="#5F5044", seg=10, flare=1.85, lean=(-0.08, 0.1))
    tips = _kit.branches(b, top, 6, s["h"] * 0.3, s["r"] * 0.42, s["h"] * 0.24, s["seed"], seg=6,
                         start=0.5, bark="#5F5044")
    centers = [t + _kit.Vector((0, 0, 0.25)) for t in tips]
    centers += [top + _kit.Vector((0, 0, s["h"] * 0.2))]
    for t in tips[::2]:                                      # secondary forks
        p = t + _kit.Vector((t.x * 0.25, t.y * 0.25, s["h"] * 0.12))
        b.pipe(t, p, s["r"] * 0.18, m=0, col="#5F5044", r2=s["r"] * 0.08, seg=5)
        centers.append(p + _kit.Vector((0, 0, 0.2)))
    _kit.leaf_masses(b, centers, s["h"] * 0.19, s["leaf"], s["seed"], sub=1, squash=0.85)


def _lod1(b, s):
    top = _kit.trunk(b, s["h"] * 0.55, s["r"], bark="#5F5044", seg=6, flare=1.25)
    _kit.leaf_masses(b, [top + _kit.Vector((0, 0, s["h"] * 0.18))], s["h"] * 0.3, s["leaf"],
                     s["seed"], sub=0, squash=0.8)


def build():
    return _kit.tree_sets("tree_maple", SPECS, _lod0, _lod1, bb_size=(5.6, 7.2))


if __name__ == "__main__":
    _kit.run(build, GLB_PATH, limits=_kit.TREE_LIMITS)
