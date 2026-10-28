"""Generate a REVIEW.md template for a QA evidence folder.

Usage: python qa/tools/make_review.py qa/evidence/<scenario> [--force]

Lists every .png (sorted) with an empty description line for the reviewer.
Existing descriptions in REVIEW.md are kept; new pngs are appended. Missing
or malformed metrics.json never crashes the script.
"""
import json
import re
import sys
from pathlib import Path


def load_metrics(folder: Path) -> dict:
    try:
        data = json.loads((folder / "metrics.json").read_text(encoding="utf-8"))
    except (OSError, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


def existing_notes(review: Path) -> dict:
    notes: dict = {}
    if not review.is_file():
        return notes
    cur = None
    for line in review.read_text(encoding="utf-8").splitlines():
        m = re.match(r"^### (.+\.png)\s*$", line)
        if m:
            cur = m.group(1)
            notes[cur] = []
        elif cur and not line.startswith("![") and line.strip():
            notes[cur].append(line)
    return notes


def main(argv: list) -> int:
    args = [a for a in argv[1:] if not a.startswith("--")]
    force = "--force" in argv
    if len(args) != 1:
        print(__doc__)
        return 2
    folder = Path(args[0])
    if not folder.is_dir():
        print(f"ERROR: not a folder: {folder}")
        return 1
    # Screenshots of before_set live in per-milestone subfolders (b0..b4); include them so
    # every image in the evidence tree is listed.
    pngs = sorted(
        str(p.relative_to(folder)).replace("\\", "/")
        for p in folder.rglob("*.png")
    )
    review = folder / "REVIEW.md"
    notes = {} if force else existing_notes(review)
    m = load_metrics(folder)
    lines = [f"# Review: {folder.name}", ""]
    if m:
        lines.append(f"metrics.json: pass={m.get('pass')}, failures={len(m.get('failures') or [])}, "
                     f"avg_fps={m.get('avg_fps')}")
    else:
        lines.append("metrics.json: missing or not an object")
    lines += [f"Screenshots: {len(pngs)}", "", "Reviewer: write 1-2 sentences per image "
              "(what is visible, what is wrong).", ""]
    for name in pngs:
        lines += [f"### {name}", f"![{name}]({name})", ""]
        lines += notes.get(name) or ["- "]
        lines.append("")
    review.write_text("\n".join(lines), encoding="utf-8")
    kept = sum(1 for n in pngs if notes.get(n))
    print(f"{review}: {len(pngs)} png listed, {kept} existing descriptions kept")
    for name in pngs:
        print(f"  {name}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
