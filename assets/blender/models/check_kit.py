"""Static checker for the iteration-2 model generators (no Blender needed).

For every contract model name it ast-parses assets/blender/models/<name>.py and verifies:
  * the file exists and parses
  * a module-level `def build()` exists (no required arguments)
  * a module-level string constant GLB_PATH exists
  * GLB_PATH == "res://assets/models/<group>/<name>.glb" with the group from the contract
  * the generator calls _kit.run(...) under __main__ (so the lead can run it directly)
  * at least 2 variants are produced (a _kit.variants(...) list of >= 2 makers, or >= 2 SPECS
    entries for the tree generators)
  * at most 2 materials are declared (count of _kit.mat(...) / tree_mats() usage)

Usage: python assets/blender/models/check_kit.py
Exit code 0 only when every row is OK.
"""
import ast
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))

PROPS = ["lamp_cobra", "lamp_lantern", "traffic_light_mast", "traffic_light_pole", "bench",
         "trash_can", "dumpster", "phone_booth", "hydrant", "mailbox", "news_box", "bus_shelter",
         "bike_rack", "bollard", "parking_meter", "sign_street", "sign_stop", "cone", "barrier",
         "scaffold_shed", "street_tree", "tree_grate", "planter", "steam_stack", "food_cart",
         "newsstand", "parked_car_sedan", "parked_car_hatch", "parked_car_van"]
ROAD = ["sidewalk_8m", "sidewalk_corner", "curb_ramp", "crosswalk_stripe", "manhole", "steam_vent"]
PARK = ["tree_oak", "tree_poplar", "tree_conifer", "tree_blossom", "tree_maple", "shrub", "hedge",
        "rock", "fountain", "bridge", "picnic_table", "playground", "statue", "park_wall"]
GROUPS = [("props", PROPS), ("road", ROAD), ("park", PARK)]
TREES_WITH_LODS = {"street_tree", "tree_oak", "tree_poplar", "tree_conifer", "tree_blossom",
                   "tree_maple"}


def _const_str(tree, name):
    for node in tree.body:
        if isinstance(node, ast.Assign):
            for t in node.targets:
                if isinstance(t, ast.Name) and t.id == name and isinstance(node.value, ast.Constant):
                    if isinstance(node.value.value, str):
                        return node.value.value
    return None


def _has_build(tree):
    for node in tree.body:
        if isinstance(node, ast.FunctionDef) and node.name == "build":
            a = node.args
            required = len(a.posonlyargs) + len(a.args) - len(a.defaults)
            return required == 0
    return False


def _calls(tree, dotted):
    """Count calls like _kit.mat(...) / _kit.variants(...) anywhere in the module."""
    out = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        f = node.func
        if isinstance(f, ast.Attribute) and isinstance(f.value, ast.Name):
            if "%s.%s" % (f.value.id, f.attr) == dotted:
                out.append(node)
        elif isinstance(f, ast.Name) and f.id == dotted:
            out.append(node)
    return out


def _variant_count(tree, name):
    best = 0
    for call in _calls(tree, "_kit.variants"):
        for arg in call.args:
            if isinstance(arg, (ast.List, ast.Tuple)):
                best = max(best, len(arg.elts))
    for call in _calls(tree, "_kit.tree_sets"):
        if len(call.args) >= 2 and isinstance(call.args[1], ast.Name):
            specs = None
            for node in tree.body:
                if isinstance(node, ast.Assign) and any(
                        isinstance(t, ast.Name) and t.id == call.args[1].id for t in node.targets):
                    specs = node.value
            if isinstance(specs, (ast.List, ast.Tuple)):
                best = max(best, len(specs.elts))
    return best


def _material_count(tree):
    n = len(_calls(tree, "_kit.mat"))
    # tree_sets()/car mats supply exactly the 2 shared materials inside the helper.
    if _calls(tree, "_kit.tree_mats") or _calls(tree, "_car.mats") or _calls(tree, "_kit.tree_sets"):
        n = max(n, 2)
    return n


def check(name, group):
    path = os.path.join(HERE, name + ".py")
    problems = []
    if not os.path.exists(path):
        return ["missing file"], {}
    with open(path, "r", encoding="utf-8") as fh:
        src = fh.read()
    try:
        tree = ast.parse(src, filename=path)
    except SyntaxError as exc:
        return ["SyntaxError line %s: %s" % (exc.lineno, exc.msg)], {}
    if not _has_build(tree):
        problems.append("no build()")
    glb = _const_str(tree, "GLB_PATH")
    want = "res://assets/models/%s/%s.glb" % (group, name)
    if glb is None:
        problems.append("no GLB_PATH")
    elif glb != want:
        problems.append("GLB_PATH %s != %s" % (glb, want))
    if not _calls(tree, "_kit.run"):
        problems.append("no _kit.run()")
    variants = _variant_count(tree, name)
    if variants < 2:
        problems.append("variants=%d (<2)" % variants)
    mats = _material_count(tree)
    if mats > 2:
        problems.append("materials=%d (>2)" % mats)
    if name in TREES_WITH_LODS and not _calls(tree, "_kit.tree_sets"):
        problems.append("no tree_sets() -> no _lod1/_bb")
    return problems, {"variants": variants, "materials": mats, "glb": glb or "-"}


def main():
    rows = []
    for group, names in GROUPS:
        for name in names:
            problems, info = check(name, group)
            rows.append((group, name, info, problems))
    width = max(len(r[1]) for r in rows)
    print("%-6s %-*s %-8s %-5s %s" % ("GROUP", width, "MODEL", "VARIANTS", "MATS", "STATUS"))
    print("-" * (width + 40))
    bad = 0
    for group, name, info, problems in rows:
        status = "OK" if not problems else "FAIL: " + "; ".join(problems)
        if problems:
            bad += 1
        print("%-6s %-*s %-8s %-5s %s" % (group, width, name, info.get("variants", "-"),
                                          info.get("materials", "-"), status))
    print("-" * (width + 40))
    print("%d models checked, %d OK, %d FAIL" % (len(rows), len(rows) - bad, bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
