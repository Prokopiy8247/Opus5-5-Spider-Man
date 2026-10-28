"""Self-test for summarize_evidence.py on fake metrics in a temp dir inside qa/tools/."""
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.join(HERE, "summarize_evidence.py")


def make(root: str, data: dict) -> None:
    for name, m in data.items():
        os.makedirs(os.path.join(root, name), exist_ok=True)
        with open(os.path.join(root, name, "metrics.json"), "w", encoding="utf-8") as f:
            f.write(m if isinstance(m, str) else json.dumps(m))


def run(data: dict) -> tuple:
    root = tempfile.mkdtemp(prefix="_fake_evidence_", dir=HERE)
    try:
        make(root, data)
        r = subprocess.run([sys.executable, TOOL, root], capture_output=True, text=True)
        return r.returncode, r.stdout
    finally:
        shutil.rmtree(root)


ok_m = {"gadget_bot": {"scenario": "gadget_bot", "pass": True, "duration_s": 12.5},
        "base_waves": {"scenario": "base_waves", "pass": True, "duration_s": 88.0}}
cases = [
    ("all pass", ok_m, 0),
    ("one fail", {**ok_m, "stealth_bot": {"scenario": "stealth_bot", "pass": False, "duration_s": 30.1}}, 1),
    ("missing pass", {**ok_m, "smoke": {"scenario": "smoke", "duration_s": 3}}, 1),
    ("bad json", {**ok_m, "load_all": "{oops"}, 1),
    ("empty", {}, 2),
]
bad = 0
for label, data, want in cases:
    got, out = run(data)
    print(f"--- {label}: want {want} got {got}")
    print(out.rstrip())
    bad += got != want
print(f"{len(cases) - bad}/{len(cases)} cases OK")
sys.exit(1 if bad else 0)
