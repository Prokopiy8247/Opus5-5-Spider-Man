"""Scan a Godot log for problems. Exit 1 if any are found, 0 if clean.

Usage: python qa/tools/check_log.py <logfile> [<logfile> ...]
"""
import re
import sys

PATTERNS = [
    ("Parser Error", re.compile(r"Parse(r)? Error", re.IGNORECASE)),
    ("Invalid access", re.compile(r"Invalid access", re.IGNORECASE)),
    ("ERROR", re.compile(r"\bERROR\b")),
    ("WARNING", re.compile(r"\bWARNING\b")),
]


def decode_log(raw: bytes) -> str:
    """Decode a log regardless of who wrote it.

    Windows PowerShell 5.1 redirection (`*>`, Out-File) writes UTF-16 LE with a BOM;
    reading that as UTF-8 yields NUL-interleaved text where no pattern matches.
    """
    if raw.startswith(b"\xff\xfe") or raw.startswith(b"\xfe\xff"):
        return raw.decode("utf-16", errors="replace")
    if raw.startswith(b"\xef\xbb\xbf"):
        return raw[3:].decode("utf-8", errors="replace")
    # BOM-less UTF-16: many NUL bytes at odd/even positions.
    if raw and raw.count(b"\x00") > len(raw) // 4:
        enc = "utf-16-le" if raw[1:2] == b"\x00" else "utf-16-be"
        return raw.decode(enc, errors="replace")
    return raw.decode("utf-8", errors="replace")


def scan(path: str) -> list[str]:
    hits: list[str] = []
    with open(path, "rb") as f:
        text = decode_log(f.read())
    for n, line in enumerate(text.splitlines(), 1):
        for label, rx in PATTERNS:
            if rx.search(line):
                hits.append(f"{path}:{n}: [{label}] {line.rstrip()}")
                break
    return hits


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__.strip())
        return 2
    hits: list[str] = []
    for p in argv:
        try:
            hits += scan(p)
        except OSError as e:
            print(f"cannot read {p}: {e}")
            return 2
    for h in hits:
        print(h)
    print(f"check_log: {len(hits)} problem line(s)" if hits else "check_log: clean")
    return 1 if hits else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
