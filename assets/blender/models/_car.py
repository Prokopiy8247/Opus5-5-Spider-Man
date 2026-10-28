"""Shared parked-car body builder used by parked_car_sedan / _hatch / _van.

One mesh per variant, 2 materials: "Car_Paint" (body) and "Car_Glass" (glass, lights, tyres tinted
through the Col vertex colour). Pivot at the ground centre, length along +Y (the car faces +Y,
which becomes -Z in Godot after export_yup).
"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(globals().get("__file__", "") or "")) or ".")
import _kit  # noqa: E402

TYRE = "#1A1C1E"
RIM = "#9DA2A6"
GLASS = "#39505E"
LIGHT = "#E8D9A8"


def mats():
    # -> M_parked_car_<kind>_body (car paint atlas, one colour per variant) and
    #    M_parked_car_<kind>_glass (glass, lights, tyres, rims; exempt from near-white rule)
    return [_kit.mat("Body", rough=0.3, metal=0.3), _kit.mat("Glass", rough=0.15)]


def wheels(b, wb, half_w, r=0.33):
    for sy in (-1, 1):
        for sx in (-1, 1):
            b.cyl(r, 0.2, (sx * half_w, sy * wb / 2, r), m=1, col=TYRE, seg=14, rot=(0, 90 * sx, 0))
            b.cyl(r * 0.58, 0.06, (sx * (half_w + 0.09), sy * wb / 2, r), m=1, col=RIM, seg=12,
                  rot=(0, 90 * sx, 0))


def body(b, paint, length, width, wb, roof_z=1.42, hood_z=0.95, cab=(-0.55, 0.75), box_tail=False,
         tail_z=None):
    """Generic three-box car: hood, cabin, trunk. cab = (y0, y1) of the cabin in metres."""
    hw = width / 2
    b.box((width, length, 0.22), (0, 0, 0.42), m=0, col=paint, bevel=0.05)                  # floor pan
    b.box((width, length * 0.98, 0.42), (0, 0, 0.72), m=0, col=paint, bevel=0.06)            # lower body
    b.box((width - 0.08, length * 0.46, hood_z - 0.9), (0, length * 0.26, hood_z - 0.06), m=0,
          col=paint, bevel=0.05)                                                             # hood
    tz = tail_z if tail_z is not None else hood_z
    b.box((width - 0.08, length * 0.3, tz - 0.9), (0, -length * 0.34, tz - 0.06), m=0, col=paint,
          bevel=0.05)                                                                        # trunk/tail
    cab_len = cab[1] - cab[0]
    cab_y = (cab[0] + cab[1]) / 2
    b.box((width - 0.1, cab_len, roof_z - hood_z + 0.18), (0, cab_y, (roof_z + hood_z) / 2 - 0.04),
          m=0, col=paint, bevel=0.06)                                                        # cabin
    b.box((width - 0.16, cab_len + 0.1, 0.06), (0, cab_y, roof_z), m=0, col=paint, bevel=0.03)  # roof
    # glass
    b.box((width - 0.14, 0.04, roof_z - hood_z - 0.02), (0, cab[1] - 0.02, (roof_z + hood_z) / 2),
          m=1, col=GLASS, bevel=0.01, rot=(26, 0, 0))                                        # windscreen
    b.box((width - 0.14, 0.04, roof_z - hood_z - 0.06), (0, cab[0] + 0.02, (roof_z + hood_z) / 2),
          m=1, col=GLASS, bevel=0.01, rot=(-22, 0, 0))                                       # rear glass
    for sx in (-1, 1):
        b.box((0.04, cab_len - 0.2, roof_z - hood_z - 0.12), (sx * (hw - 0.07), cab_y,
              (roof_z + hood_z) / 2 - 0.02), m=1, col=GLASS, bevel=0.01)                     # side glass
        b.box((0.1, 0.16, 0.1), (sx * (hw + 0.03), cab[1] - 0.12, hood_z + 0.08), m=0, col=paint,
              bevel=0.02)                                                                    # mirror
        b.box((0.06, 0.3, 0.1), (sx * (hw - 0.02), length * 0.47, hood_z - 0.18), m=1, col=LIGHT,
              bevel=0.015)                                                                   # headlight
        b.box((0.06, 0.1, 0.12), (sx * (hw - 0.02), -length * 0.47, hood_z - 0.16), m=1,
              col="#8E2A22", bevel=0.012)                                                    # tail light
    b.box((width + 0.04, 0.16, 0.2), (0, length * 0.49, 0.56), m=0, col="#3A3D40", bevel=0.03)
    b.box((width + 0.04, 0.16, 0.2), (0, -length * 0.49, 0.56), m=0, col="#3A3D40", bevel=0.03)
    b.box((width - 0.3, 0.1, 0.14), (0, length * 0.5, hood_z - 0.3), m=1, col="#2A2D30", bevel=0.02)
    if box_tail:
        b.box((width - 0.06, 0.05, roof_z - hood_z - 0.1), (0, -length * 0.49,
              (roof_z + hood_z) / 2), m=1, col=GLASS, bevel=0.01)
    wheels(b, wb, hw - 0.02)
