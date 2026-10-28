"""Static texture check for the 49 kit generators (no Blender needed).

Verifies:
  * _kit.py: mat() creates a ShaderNodeTexImage linked to Principled 'Base Color', run() calls
    bake(), bake() saves PNGs into textures/<model>/, no vertex-colour (COLOR_0) export remains.
  * every generator: gets its materials only through _kit.mat / _car.mats / tree_mats / tree_sets
    (which all bake a texture), creates no raw bpy materials, and every part call
    (box/cyl/pipe/sphere/blob/quad) uses a material index m that exists (< number of materials).
Usage: python assets/blender/models/check_textures.py   -> prints "<n> generators without textures"
"""
import ast
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from check_kit import GROUPS, _calls  # noqa: E402

PARTS = {"box", "cyl", "pipe", "sphere", "blob", "quad"}


def check_kit_core():
    src = open(os.path.join(HERE, "_kit.py"), encoding="utf-8").read()
    probs = []
    for needle, why in (("ShaderNodeTexImage", "mat() has no image texture"),
                        ('bsdf.inputs["Base Color"]', "texture not linked to Base Color"),
                        ("bake(mname)", "run() does not bake"),
                        ("TEX_DIR", "no textures/ dir"),
                        ('"Kit_" + name', "reset not scoped to Kit_<name>")):
        if needle not in src:
            probs.append(why)
    if 'export_vertex_color="ACTIVE"' in src or "ShaderNodeVertexColor" in src:
        probs.append("vertex colours still used")
    return probs


def check_gen(name):
    path = os.path.join(HERE, name + ".py")
    tree = ast.parse(open(path, encoding="utf-8").read())
    probs = []
    nmat = len(_calls(tree, "_kit.mat"))
    if _calls(tree, "_car.mats") or _calls(tree, "_kit.tree_mats") or _calls(tree, "_kit.tree_sets"):
        nmat = max(nmat, 2)
    if nmat == 0:
        probs.append("no textured material")
    for node in ast.walk(tree):
        if isinstance(node, ast.Attribute) and node.attr in ("materials", "new") and \
                "bpy.data.materials" in ast.unparse(node):
            probs.append("raw bpy material (untextured)")
            break
    for node in ast.walk(tree):
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute) and node.func.attr in PARTS:
            for kw in node.keywords:
                if kw.arg == "m" and isinstance(kw.value, ast.Constant) and kw.value.value >= max(nmat, 1):
                    probs.append("part line %d uses m=%d without material" % (node.lineno, kw.value.value))
    return probs


def main():
    core = check_kit_core()
    print("_kit.py:", "OK" if not core else "FAIL: " + "; ".join(core))
    bad = 0
    total = 0
    for _group, names in GROUPS:
        for n in names:
            total += 1
            p = check_gen(n) + core
            if p:
                bad += 1
                print("FAIL %-20s %s" % (n, "; ".join(p)))
    print("%d generators checked, %d generators without textures" % (total, bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
