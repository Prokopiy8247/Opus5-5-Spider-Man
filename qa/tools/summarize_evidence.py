"""Prints scenario|pass|duration for every qa/evidence/*/metrics.json.

Exit 1 if any pass is false (or a metrics file is unreadable), 2 if none found.
Usage: python qa/tools/summarize_evidence.py [evidence_dir]
"""
import glob
import json
import os
import sys

DEFAULT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "evidence")


def main(argv: list) -> int:
    root = argv[1] if len(argv) > 1 else DEFAULT
    files = sorted(glob.glob(os.path.join(root, "*", "metrics.json")))
    if not files:
        print(f"no metrics.json under {root}")
        return 2
    rows = []
    bad = 0
    for f in files:
        name = os.path.basename(os.path.dirname(f))
        try:
            with open(f, encoding="utf-8-sig") as fh:
                m = json.load(fh)
            ok = m.get("pass") is True
            dur = m.get("duration_s")
            dur_s = f"{float(dur):.2f}" if isinstance(dur, (int, float)) else "?"
            rows.append((str(m.get("scenario", name)), "true" if ok else "false", dur_s))
        except (OSError, ValueError) as e:
            ok = False
            rows.append((name, "false", f"unreadable: {e.__class__.__name__}"))
        bad += not ok
    w = max(len("scenario"), *(len(r[0]) for r in rows))
    print(f"{'scenario'.ljust(w)} | pass  | duration")
    print(f"{'-' * w}-|-------|---------")
    for s, p, d in rows:
        print(f"{s.ljust(w)} | {p.ljust(5)} | {d}")
    print(f"{len(rows) - bad}/{len(rows)} passed")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
