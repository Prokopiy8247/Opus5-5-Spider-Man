# Helper (run with python) that writes the 5 one-shot VFX scenes into scenes/vfx/.
import os
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SPEC = {"hit_spark": ("spark", 0.4), "land_dust": ("dust", 1.0), "shockwave": ("shockwave", 0.5),
        "cocoon": ("cocoon", 6.0), "explosion": ("explosion", 1.8)}
for name, (kind, life) in SPEC.items():
    txt = ('[gd_scene load_steps=2 format=3]\n\n'
           '[ext_resource type="Script" path="res://scripts/ui/vfx_burst.gd" id="1"]\n\n'
           f'[node name="{name}" type="Node3D"]\nscript = ExtResource("1")\nkind = "{kind}"\nlifetime = {life}\n')
    p = os.path.join(ROOT, "scenes", "vfx", name + ".tscn")
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "w", newline="\n").write(txt)
    print("wrote", p)
