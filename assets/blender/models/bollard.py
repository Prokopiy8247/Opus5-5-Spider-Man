"""Bollards: v1 steel pipe with reflective bands, v2 cast-iron ornamental, v3 short granite stub."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/bollard.glb"


def _v1(b):
    col = "#8A8F94"
    b.cyl(0.18, 0.05, (0, 0, 0), m=0, col=col, seg=14, bevel=0.012)
    b.cyl(0.11, 0.9, (0, 0, 0.05), m=0, col=col, seg=14)
    b.cyl(0.115, 0.07, (0, 0, 0.62), m=1, col="#E2E2D8", seg=14)
    b.cyl(0.115, 0.07, (0, 0, 0.78), m=1, col="#E2E2D8", seg=14)
    b.cyl(0.11, 0.06, (0, 0, 0.95), m=0, col=col, r2=0.07, seg=14, bevel=0.015)


def _v2(b):
    col = "#23262A"
    b.cyl(0.22, 0.08, (0, 0, 0), m=0, col=col, seg=12, bevel=0.015)
    b.cyl(0.17, 0.12, (0, 0, 0.08), m=0, col=col, r2=0.12, seg=12)
    b.cyl(0.1, 0.62, (0, 0, 0.2), m=0, col=col, r2=0.085, seg=12)
    b.cyl(0.14, 0.07, (0, 0, 0.82), m=0, col=col, r2=0.1, seg=12, bevel=0.012)
    b.sphere(0.1, (0, 0, 0.96), m=0, col=col, seg=12, rings=7)
    b.cyl(0.12, 0.03, (0, 0, 0.46), m=1, col="#55595E", seg=12)


def _v3(b):
    col = "#8E8B84"
    b.cyl(0.19, 0.55, (0, 0, 0), m=0, col=col, r2=0.17, seg=8, bevel=0.02)
    b.cyl(0.17, 0.06, (0, 0, 0.55), m=0, col=col, r2=0.1, seg=8, bevel=0.02)


def build():
    m = [_kit.mat("Bollard_Body", rough=0.55, metal=0.4), _kit.mat("Bollard_Band", rough=0.3)]
    return _kit.variants("bollard", m, [_v1, _v2, _v3], spacing=1.0)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
