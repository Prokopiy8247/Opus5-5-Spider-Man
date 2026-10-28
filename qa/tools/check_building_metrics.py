"""Validate the iteration-3 building metrics files and print PASS/FAIL per check.

Usage: python qa/tools/check_building_metrics.py <metrics.json> [more metrics.json ...]

Recognised files (by the "scenario" field, or the parent folder name):
  facade_bot        - full gate set (keys, density, shimmer, texture memory, FPS, draw calls)
  building_gallery  - 14 styles x 3 variants, day/night close/mid shot count
  before_set        - 10 views for the milestone tag

Exit code 0 when every check passed, 1 when any check failed or a file is unusable.
A missing file is reported as FAIL, not an exception.
"""
import json
import sys
from pathlib import Path

# contract keys every building metrics.json must carry
CONTRACT_KEYS = [
    "fps_avg", "fps_1pct_low", "draw_calls", "texture_mem_mb",
    "texel_density_px_m", "shimmer_score", "distinct_looks",
    "adjacent_identical", "styles_seen",
]
DENSITY_MIN = 200.0
SHIMMER_MAX = 0.012
TEX_MEM_MAX_MB = 512.0
FPS_AVG_MIN = 120.0
FPS_LOW_MIN = 60.0
DRAW_CALL_FACTOR = 1.25
MIN_DISTINCT_LOOKS = 30
STYLES = 14
VARIANTS = 3


class Report:
    def __init__(self) -> None:
        self.failed = 0
        self.passed = 0

    def check(self, name: str, ok: bool, detail: str = "") -> bool:
        tail = f" ({detail})" if detail else ""
        print(f"  {'PASS' if ok else 'FAIL'} {name}{tail}")
        if ok:
            self.passed += 1
        else:
            self.failed += 1
        return ok


def load(path: Path) -> dict | None:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        print(f"  FAIL readable ({exc.strerror or exc})")
        return None
    except ValueError as exc:
        print(f"  FAIL valid json ({exc})")
        return None
    if not isinstance(data, dict):
        print("  FAIL json object (top level is not an object)")
        return None
    return data


def as_floats(value: object) -> list:
    if not isinstance(value, list):
        return []
    return [float(v) for v in value if isinstance(v, (int, float))]


def check_facade_bot(m: dict, r: Report) -> None:
    missing = [k for k in CONTRACT_KEYS if k not in m]
    r.check("contract keys", not missing, "missing: " + ", ".join(missing) if missing else "9/9")

    dens = as_floats(m.get("texel_density_px_m"))
    worst = min(dens) if dens else 0.0
    r.check("texel density near ground >= %.0f px/m" % DENSITY_MIN,
            bool(dens) and worst >= DENSITY_MIN, "min %.1f over %d samples" % (worst, len(dens)))

    sh = as_floats(m.get("shimmer_score"))
    worst_sh = max(sh) if sh else 0.0
    r.check("shimmer at 300 m <= %.4f" % SHIMMER_MAX,
            bool(sh) and worst_sh <= SHIMMER_MAX, "max %.5f over %d samples" % (worst_sh, len(sh)))

    tex = float(m.get("texture_mem_mb") or 0.0)
    r.check("texture memory <= %.0f MB" % TEX_MEM_MAX_MB, tex <= TEX_MEM_MAX_MB, "%.1f MB" % tex)

    avg = float(m.get("fps_avg") or 0.0)
    low = float(m.get("fps_1pct_low") or 0.0)
    r.check("fps_avg >= %.0f" % FPS_AVG_MIN, avg >= FPS_AVG_MIN, "%.1f" % avg)
    r.check("fps_1pct_low >= %.0f" % FPS_LOW_MIN, low >= FPS_LOW_MIN, "%.1f" % low)

    draws = float(m.get("draw_calls") or 0.0)
    base = float(m.get("draw_calls_baseline") or 0.0)
    limit = base * DRAW_CALL_FACTOR
    if base <= 0.0:
        r.check("draw calls <= 125% of baseline", False, "baseline missing in metrics")
    else:
        r.check("draw calls <= 125% of baseline", draws <= limit,
                "%.0f of limit %.0f (baseline %.0f)" % (draws, limit, base))

    adj = m.get("adjacent_identical")
    r.check("adjacent_identical == 0", adj == 0, f"{adj}")
    looks = int(m.get("distinct_looks") or 0)
    r.check("distinct_looks >= %d" % MIN_DISTINCT_LOOKS, looks >= MIN_DISTINCT_LOOKS, str(looks))
    seen = int(m.get("styles_seen") or 0)
    r.check("styles_seen == %d" % STYLES, seen == STYLES, str(seen))
    r.check("scenario pass flag", bool(m.get("pass")), "failures: %d" % len(m.get("failures") or []))


def check_building_gallery(m: dict, r: Report) -> None:
    shots = m.get("screenshots") or []
    expected = STYLES * VARIANTS * 4  # close + mid, day + night
    r.check("lots == %d" % (STYLES * VARIANTS), int(m.get("lots") or 0) == STYLES * VARIANTS,
            str(m.get("lots")))
    r.check("screenshots == %d" % expected, len(shots) == expected, str(len(shots)))
    for kind in ("close_day", "close_night", "mid_day", "mid_night"):
        n = sum(1 for s in shots if str(s).endswith(kind + ".png"))
        r.check("%s shots == %d" % (kind, STYLES * VARIANTS), n == STYLES * VARIANTS, str(n))
    r.check("scenario pass flag", bool(m.get("pass")), "failures: %d" % len(m.get("failures") or []))


def check_before_set(m: dict, r: Report) -> None:
    tag = str(m.get("tag") or "")
    r.check("tag in b0..b4", tag in {"b0", "b1", "b2", "b3", "b4"}, tag or "missing")
    shots = m.get("screenshots") or []
    r.check("views == 10", int(m.get("views") or 0) == 10, str(m.get("views")))
    r.check("screenshots == 10", len(shots) == 10, str(len(shots)))
    r.check("scenario pass flag", bool(m.get("pass")), "failures: %d" % len(m.get("failures") or []))


CHECKS = {
    "facade_bot": check_facade_bot,
    "building_gallery": check_building_gallery,
    "before_set": check_before_set,
}


# Sample metrics used by --selftest (one passing and one failing set per scenario).
# They live in the script because qa/tools/*.json is outside this file's ownership.
SAMPLES: dict = {
    "facade_bot_pass": {
        "scenario": "facade_bot", "pass": True, "failures": [], "locations": 10,
        "fps_avg": 158.4, "fps_1pct_low": 81.2, "draw_calls": 3900.0,
        "draw_calls_baseline": 4811.0, "draw_calls_limit": 6013.8, "texture_mem_mb": 412.5,
        "texel_density_px_m": [379.3, 379.3, 320.0, 290.5],
        "shimmer_score": [0.0031, 0.0045, 0.0022], "shimmer_max": 0.012,
        "distinct_looks": 42, "adjacent_identical": 0, "styles_seen": 14, "buildings": 1180,
        "screenshots": ["00_loc00_street_corner_003m_day.png"],
    },
    "facade_bot_fail": {
        "scenario": "facade_bot", "pass": False,
        "failures": ["texel density 140 px/m below 200 near ground"],
        "fps_avg": 96.0, "fps_1pct_low": 42.0, "draw_calls": 7200.0,
        "draw_calls_baseline": 4811.0, "texture_mem_mb": 690.0,
        "texel_density_px_m": [140.0, 379.3], "shimmer_score": [0.031],
        "distinct_looks": 18, "adjacent_identical": 7, "styles_seen": 11, "screenshots": [],
    },
    "building_gallery_pass": {
        "scenario": "building_gallery", "pass": True, "failures": [], "lots": 42,
        "screenshots": [
            "%02d_s%02d_v%d_%s.png" % (i, i // 3, i % 3, kind)
            for i in range(STYLES * VARIANTS)
            for kind in ("close_day", "close_night", "mid_day", "mid_night")
        ],
    },
    "building_gallery_fail": {
        "scenario": "building_gallery", "pass": False, "failures": ["12 lots, expected 42"],
        "lots": 12, "screenshots": ["00_s00_v0_close_day.png"],
    },
    "before_set_pass": {
        "scenario": "before_set", "pass": True, "failures": [], "tag": "b0", "views": 10,
        "screenshots": ["%02d_view.png" % i for i in range(10)],
    },
    "before_set_fail": {
        "scenario": "before_set", "pass": False, "failures": ["3 of 10 views saved"],
        "tag": "bX", "views": 10, "screenshots": ["00_view.png"],
    },
}


def selftest() -> int:
    """Runs every sample through the checks; the *_pass samples must pass, *_fail must fail."""
    import tempfile

    bad = 0
    with tempfile.TemporaryDirectory() as tmp:
        for name, data in SAMPLES.items():
            path = Path(tmp) / name / "metrics.json"
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(data, indent=2), encoding="utf-8")
            print(f"== sample {name}")
            r = Report()
            CHECKS[str(data["scenario"])](data, r)
            want_pass = name.endswith("_pass")
            got_pass = r.failed == 0
            verdict = "PASS" if got_pass == want_pass else "FAIL"
            print("  -> %s: %d PASS, %d FAIL (expected %s)"
                  % (verdict, r.passed, r.failed, "all PASS" if want_pass else "some FAIL"))
            if verdict == "FAIL":
                bad += 1
        # a missing and a malformed file must be reported, not raised
        broken = Path(tmp) / "facade_bot" / "metrics.json"
        broken.parent.mkdir(parents=True, exist_ok=True)
        broken.write_text("{not json", encoding="utf-8")
        print("== sample malformed + missing")
        code = main(["check_building_metrics.py", str(broken), str(Path(tmp) / "nope.json")])
        print("  -> exit %d (expected 1)" % code)
        if code != 1:
            bad += 1
    print("-- selftest %s (%d unexpected)" % ("OK" if bad == 0 else "FAILED", bad))
    return 1 if bad else 0


def main(argv: list) -> int:
    if "--selftest" in argv:
        return selftest()
    paths = [a for a in argv[1:] if not a.startswith("--")]
    if not paths:
        print(__doc__)
        return 2
    r = Report()
    for raw in paths:
        path = Path(raw)
        print(f"== {path}")
        if not path.is_file():
            r.check("file exists", False, str(path))
            continue
        m = load(path)
        if m is None:
            r.failed += 1
            continue
        name = str(m.get("scenario") or path.parent.name)
        fn = CHECKS.get(name)
        if fn is None:
            r.check("known scenario", False, name)
            continue
        fn(m, r)
    print(f"-- {r.passed} PASS, {r.failed} FAIL")
    return 1 if r.failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
