"""Work-zone barriers: v1 A-frame striped barricade, v2 plastic water barrier, v3 steel pedestrian fence."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/barrier.glb"


def _v1(b):
    wood = "#D9D3C4"
    leg = "#C85A14"
    for sx in (-1, 1):
        b.box((0.07, 0.07, 1.06), (sx * 0.95, -0.2, 0.53), m=0, col=leg, bevel=0.012, rot=(10, 0, 0))
        b.box((0.07, 0.07, 1.06), (sx * 0.95, 0.2, 0.53), m=0, col=leg, bevel=0.012, rot=(-10, 0, 0))
        b.box((0.06, 0.5, 0.05), (sx * 0.95, 0, 0.42), m=0, col=leg, bevel=0.008)
    for z in (0.72, 0.98):
        b.box((2.1, 0.05, 0.22), (0, 0, z), m=1, col=wood, bevel=0.01)
        for i in range(5):
            b.box((0.2, 0.012, 0.22), (-0.8 + i * 0.4, -0.032, z), m=1, col="#C03A1E",
                  bevel=0.004, rot=(0, 28, 0))


def _v2(b):
    body = "#E2771C"
    b.box((1.95, 0.5, 0.18), (0, 0, 0.09), m=0, col=body, bevel=0.03)
    b.box((1.75, 0.3, 0.6), (0, 0, 0.42), m=0, col=body, bevel=0.04)
    b.box((1.9, 0.42, 0.14), (0, 0, 0.78), m=0, col=body, bevel=0.03)
    for x in (-0.55, 0.0, 0.55):
        b.box((0.08, 0.34, 0.5), (x, 0, 0.44), m=0, col=body, bevel=0.015)
    b.box((1.8, 0.02, 0.1), (0, -0.16, 0.78), m=1, col="#F2F0E8", bevel=0.004)
    b.cyl(0.06, 0.16, (0.9, 0, 0.5), m=1, col="#2E3034", seg=8, rot=(0, 90, 0))


def _v3(b):
    steel = "#5E646A"
    for sx in (-1, 1):
        b.box((0.05, 0.42, 1.1), (sx * 1.1, 0, 0.55), m=0, col=steel, bevel=0.01)
        b.box((0.07, 0.6, 0.05), (sx * 1.1, 0, 0.025), m=1, col=steel, bevel=0.01)
    for z in (0.18, 0.64, 1.08):
        b.pipe((-1.1, 0, z), (1.1, 0, z), 0.022, m=0, col=steel, seg=8)
    for i in range(9):
        x = -1.0 + i * 0.25
        b.pipe((x, 0, 0.18), (x, 0, 1.08), 0.014, m=0, col=steel, seg=6)


def build():
    m = [_kit.mat("Barrier_Body", rough=0.6, metal=0.2), _kit.mat("Barrier_Stripe", rough=0.35)]
    return _kit.variants("barrier", m, [_v1, _v2, _v3], spacing=2.6)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
