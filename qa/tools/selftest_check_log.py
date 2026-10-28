"""Self-test for check_log.py: WARNING log -> 1, clean log -> 0."""
import os
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.join(HERE, "check_log.py")


def run(text: str, encoding: str = "utf-8") -> int:
    fd, p = tempfile.mkstemp(suffix=".log")
    with os.fdopen(fd, "wb") as f:
        # "utf-16" adds a BOM, like Windows PowerShell 5.1 `*>` redirection.
        f.write(text.encode(encoding))
    try:
        return subprocess.run([sys.executable, TOOL, p], capture_output=True).returncode
    finally:
        os.remove(p)


cases = [
    ("Godot Engine v4.7\n[QA] scenario smoke PASS\n", 0),
    ("WARNING: something odd\n   at: foo (res://a.gd:3)\n", 1),
    ("ERROR: boom\n", 1),
    ("SCRIPT ERROR: Parse Error: x\n", 1),
    ("Invalid access to property or key 'x'\n", 1),
]
bad = 0
for enc in ("utf-8", "utf-8-sig", "utf-16", "utf-16-le"):
    for text, want in cases:
        got = run(text, enc)
        print(f"[{enc}] want {want} got {got}: {text.splitlines()[0]}")
        bad += got != want
sys.exit(1 if bad else 0)
