"""Byte-compile every generator in this folder (syntax check without Blender).

Usage: python assets/blender/models/compile_all.py
"""
import ast
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    bad = []
    names = sorted(f for f in os.listdir(HERE) if f.endswith(".py"))
    for f in names:
        path = os.path.join(HERE, f)
        with open(path, "r", encoding="utf-8") as fh:
            src = fh.read()
        try:
            compile(src, path, "exec", ast.PyCF_ONLY_AST)
            compile(src, path, "exec")
        except SyntaxError as exc:
            bad.append((f, "line %s: %s" % (exc.lineno, exc.msg)))
    for f, msg in bad:
        print("FAIL %s: %s" % (f, msg))
    print("%d files, %d ok, %d failed" % (len(names), len(names) - len(bad), len(bad)))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
