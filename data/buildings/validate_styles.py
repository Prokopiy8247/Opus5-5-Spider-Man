"""Validates data/buildings/styles.json against the iteration-3 building contract."""
import json
import os
import sys

NAMES = ["red_brick_tenement", "tan_brick_prewar", "brownstone", "artdeco_limestone",
         "glass_bluegreen", "glass_dark_steel", "brutalist_concrete", "white_terracotta",
         "midcentury_ribbon", "steel_glass_spandrel", "industrial_warehouse",
         "mixed_podium_tower", "landmark_limestone", "bridge_masonry_steel"]
DISTRICTS = {"downtown", "midtown", "residential", "waterfront", "base", "landmark", "bridge"}


def main() -> int:
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "styles.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    errs = []
    styles = data.get("styles", [])
    if len(styles) != 14:
        errs.append("expected 14 styles, got %d" % len(styles))
    covered = set()
    for i, s in enumerate(styles):
        if s.get("id") != i:
            errs.append("style %d: id %r out of order" % (i, s.get("id")))
        if i < 14 and s.get("name") != NAMES[i]:
            errs.append("style %d: name %r != %s" % (i, s.get("name"), NAMES[i]))
        ds = s.get("districts", [])
        if not ds or not set(ds) <= DISTRICTS:
            errs.append("style %d: bad districts %r" % (i, ds))
        covered |= set(ds)
        if not (0 <= s.get("min_h", -1) < s.get("max_h", -1)):
            errs.append("style %d: bad height range" % i)
        gt = s.get("ground_types", [])
        if not gt or any(not isinstance(g, int) or g < 0 or g > 5 for g in gt):
            errs.append("style %d: bad ground_types %r" % (i, gt))
    if covered != DISTRICTS:
        errs.append("districts without styles: %s" % sorted(DISTRICTS - covered))
    if styles and styles[2].get("ground_types") != [3]:
        errs.append("brownstone must use ground type 3 (stoop)")
    if any(12 in [x["id"]] and x["districts"] != ["landmark"] for x in styles):
        errs.append("style 12 must be landmark-only")
    if any(13 in [x["id"]] and x["districts"] != ["bridge"] for x in styles):
        errs.append("style 13 must be bridge-only")
    for d in sorted(DISTRICTS - {"landmark", "bridge"}):
        n = sum(1 for s in styles if d in s["districts"])
        print("district %-12s %d styles" % (d, n))
    for e in errs:
        print("FAIL", e)
    print("PASS styles.json" if not errs else "FAIL styles.json (%d errors)" % len(errs))
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
