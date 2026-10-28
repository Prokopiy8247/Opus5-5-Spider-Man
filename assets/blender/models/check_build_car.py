"""Syntax/contract check for build_car.py without Blender."""
import ast
import os
import sys

OBJECTS = ["Body", "Cabin", "Windows", "Bumpers", "Grille", "Mirrors",
           "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR", "Headlights", "Brakelights"]
MATERIALS = ["Car_Paint", "Car_Glass", "Car_Tire", "Car_Rim", "Car_Trim", "Car_Headlight", "Car_Brakelight"]
EXTRA = ["export_yup=True", "export_apply=True", "car.glb", "BEVEL", "bmesh"]

path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "build_car.py")
src = open(path, encoding="utf-8").read()
tree = ast.parse(src)
strings = {n.value for n in ast.walk(tree) if isinstance(n, ast.Constant) and isinstance(n.value, str)}
missing = [n for n in OBJECTS + MATERIALS if n not in strings]
missing += [n for n in EXTRA if n not in src]
print("objects (%d): %s" % (len(OBJECTS), ", ".join(OBJECTS)))
print("materials (%d): %s" % (len(MATERIALS), ", ".join(MATERIALS)))
print("OK" if not missing else "missing: %s" % missing)
sys.exit(1 if missing else 0)
