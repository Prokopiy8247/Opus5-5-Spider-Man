"""Build the low-poly shared enemy body and export assets/models/enemy.glb.

Run: blender -b --python assets/blender/models/build_enemy.py  (or exec via Blender MCP).
Archetype variants recolour Suit_Primary/Suit_Secondary/Suit_Emblem at runtime.
"""
import os
import sys

import bpy

_here = os.path.dirname(os.path.abspath(globals().get("__file__", "") or ""))
if not os.path.exists(os.path.join(_here, "_humanoid.py")) and bpy.data.filepath:
    _here = os.path.join(os.path.dirname(bpy.data.filepath), "assets", "blender", "models")
if _here not in sys.path:
    sys.path.insert(0, _here)

import _humanoid  # noqa: E402

_humanoid.build(
    os.path.join(_here, "build_enemy.py"), "enemy.glb", "Enemy",
    {"primary": "#3A3F44", "secondary": "#1E2124", "emblem": "#D9A400"},
    bulk=1.15, extra_hex="#C9A27E",
    extra_clips=_humanoid.KO_CLIPS,  # ko_back, ko_front, ko_side, ko_heavy (+ legacy 'death')
)
