"""Run every iteration-2 generator inside one Blender process and export all .glb files.

Usage: W:\\Blender\\blender.exe -b --python assets/blender/models/export_all.py [-- name1 name2]
Prints one SUMMARY line; exit code 1 when any generator failed or a model broke its limits.
"""
import os
import runpy
import sys
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import check_kit  # noqa: E402
import _kit  # noqa: E402

names = [n for _, group in check_kit.GROUPS for n in group]
if "--" in sys.argv:
    names = sys.argv[sys.argv.index("--") + 1:] or names

failed, over = [], []
for n in names:
    try:
        g = runpy.run_path(os.path.join(HERE, n + ".py"), run_name="kit_batch")
        limits = _kit.TREE_LIMITS if n in check_kit.TREES_WITH_LODS else None
        rows = _kit.run(g["build"], g["GLB_PATH"], limits)
        over += [r[0] for r in rows if not r[3]]
    except Exception:
        traceback.print_exc()
        failed.append(n)
print("SUMMARY models=%d failed=%s over_limit=%s" % (len(names), failed, over))
sys.exit(1 if failed or over else 0)
