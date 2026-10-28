"""Street name signs on a post: v1 single blade, v2 crossed blades at a corner, v3 blade + no-parking plate."""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

GLB_PATH = "res://assets/models/props/sign_street.glb"

POST = "#5A5F63"


def _post(b, h):
    b.cyl(0.09, 0.05, (0, 0, 0), m=0, col=POST, seg=10, bevel=0.01)
    b.box((0.05, 0.05, h), (0, 0, h / 2), m=0, col=POST, bevel=0.008)


def _blade(b, z, rot_z, col="#1E6B3A", w=1.1):
    b.box((w, 0.025, 0.22), (0, 0, z), m=1, col=col, bevel=0.01, rot=(0, 0, rot_z))
    b.box((w - 0.06, 0.012, 0.03), (0, 0, z + 0.07), m=1, col="#E8EDE8", bevel=0.004, rot=(0, 0, rot_z))
    b.box((w - 0.06, 0.012, 0.03), (0, 0, z - 0.07), m=1, col="#E8EDE8", bevel=0.004, rot=(0, 0, rot_z))


def _v1(b):
    _post(b, 2.6)
    _blade(b, 2.45, 0)


def _v2(b):
    _post(b, 2.8)
    _blade(b, 2.66, 0)
    _blade(b, 2.4, 90, col="#1E4F6B")


def _v3(b):
    _post(b, 2.6)
    _blade(b, 2.45, 0)
    b.box((0.32, 0.02, 0.5), (0, 0, 1.75), m=1, col="#E6E8EA", bevel=0.008)
    b.box((0.26, 0.012, 0.1), (0, -0.016, 1.88), m=1, col="#B23A30", bevel=0.004)
    b.box((0.26, 0.012, 0.1), (0, -0.016, 1.64), m=1, col="#2A4C86", bevel=0.004)


def build():
    m = [_kit.mat("Sign_Post", rough=0.5, metal=0.5), _kit.mat("Sign_Face", rough=0.35)]
    return _kit.variants("sign_street", m, [_v1, _v2, _v3], spacing=2.0)


if __name__ == "__main__":
    _kit.run(build, GLB_PATH)
