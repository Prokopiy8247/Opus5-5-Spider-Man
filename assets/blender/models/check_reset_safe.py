"""Regression: building models must not delete unrelated objects in the open .blend.

Usage: W:\\Blender\\blender.exe -b --factory-startup --python assets/blender/models/check_reset_safe.py
Exports go to a temp folder so the project glbs are not touched.
"""
import os
import runpy
import sys
import tempfile

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import _kit  # noqa: E402

tmp = tempfile.mkdtemp()
_kit.glb_abs = lambda p, s="": os.path.join(tmp, os.path.basename(p).replace(".glb", s + ".glb"))

me = bpy.data.meshes.new("Sentinel")
keep = bpy.data.objects.new("Sentinel_Hero", me)
bpy.context.scene.collection.objects.link(keep)

errs = []
for n in ("bench", "hydrant", "bench"):
    g = runpy.run_path(os.path.join(HERE, n + ".py"), run_name="kit_batch")
    _kit.run(g["build"], g["GLB_PATH"])
    if bpy.data.objects.get("Sentinel_Hero") is None:
        errs.append("sentinel deleted by " + n)
for n in ("bench", "hydrant"):
    c = bpy.data.collections.get("Kit_" + n)
    if c is None or len(c.objects) == 0:
        errs.append("no objects in Kit_" + n)
cb = len(bpy.data.collections["Kit_bench"].objects)
print("Kit_bench objects after 2 builds:", cb)
print("RESULT", "FAIL " + str(errs) if errs else "PASS")
sys.exit(1 if errs else 0)
