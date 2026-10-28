"""Build the low-poly hero and export assets/models/hero.glb.

Run: blender -b --python assets/blender/models/build_hero.py  (or exec via Blender MCP).
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

# Default "classic" suit: original red/blue with a white emblem and white lenses.
_humanoid.build(
    os.path.join(_here, "build_hero.py"), "hero.glb", "Hero",
    {"primary": "#C8102E", "secondary": "#1B3A8C", "emblem": "#F2F2F2"},
    bulk=1.0, extra_hex="#FFFFFF",
)
