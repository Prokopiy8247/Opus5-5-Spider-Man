"""Shared low-poly humanoid builder (Blender 4.x / bpy).

Builds a box-segment humanoid rigidly skinned to the contract rig "Humanoid",
creates the 17 contract clips as actions (each pushed to its own NLA track so
the glTF exporter writes every clip by name) and exports a .glb.
Suit colours live in materials Suit_Primary, Suit_Secondary and Suit_Emblem.
"""
import math
import os

import bpy

BONES = [
    # name, parent, head, tail
    ("Hips", None, (0, 0, 0.95), (0, 0, 1.08)),
    ("Spine", "Hips", (0, 0, 1.08), (0, 0, 1.25)),
    ("Chest", "Spine", (0, 0, 1.25), (0, 0, 1.45)),
    ("Neck", "Chest", (0, 0, 1.45), (0, 0, 1.55)),
    ("Head", "Neck", (0, 0, 1.55), (0, 0, 1.80)),
    ("UpperArm.L", "Chest", (0.20, 0, 1.42), (0.46, 0, 1.42)),
    ("LowerArm.L", "UpperArm.L", (0.46, 0, 1.42), (0.70, 0, 1.42)),
    ("Hand.L", "LowerArm.L", (0.70, 0, 1.42), (0.80, 0, 1.42)),
    ("UpperArm.R", "Chest", (-0.20, 0, 1.42), (-0.46, 0, 1.42)),
    ("LowerArm.R", "UpperArm.R", (-0.46, 0, 1.42), (-0.70, 0, 1.42)),
    ("Hand.R", "LowerArm.R", (-0.70, 0, 1.42), (-0.80, 0, 1.42)),
    ("UpperLeg.L", "Hips", (0.10, 0, 0.95), (0.10, 0, 0.52)),
    ("LowerLeg.L", "UpperLeg.L", (0.10, 0, 0.52), (0.10, 0, 0.08)),
    ("Foot.L", "LowerLeg.L", (0.10, 0, 0.08), (0.10, -0.16, 0.0)),
    ("UpperLeg.R", "Hips", (-0.10, 0, 0.95), (-0.10, 0, 0.52)),
    ("LowerLeg.R", "UpperLeg.R", (-0.10, 0, 0.52), (-0.10, 0, 0.08)),
    ("Foot.R", "LowerLeg.R", (-0.10, 0, 0.08), (-0.10, -0.16, 0.0)),
]

CLIPS = ["idle", "run", "sprint", "jump", "fall", "swing", "zip", "wall_run",
         "land_hero", "roll", "punch_1", "punch_2", "punch_3", "dodge",
         "finisher", "hit", "death"]
# Enemy-only one-shot KO clips (30-48 frames, end lying flat). 'death' stays as a copy of ko_back.
KO_CLIPS = ["ko_back", "ko_front", "ko_side", "ko_heavy"]

FPS = 30


def project_root(script_file):
    if script_file and os.path.exists(script_file):
        return os.path.abspath(os.path.join(os.path.dirname(script_file), "..", "..", ".."))
    if bpy.data.filepath:  # MCP: Opus5.5SpiderMan.blend sits in the project root
        return os.path.dirname(bpy.data.filepath)
    return os.getcwd()


def hex_color(h):
    h = h.lstrip("#")
    srgb = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    return (lin[0], lin[1], lin[2], 1.0)


def reset_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()
    for coll in (bpy.data.meshes, bpy.data.armatures, bpy.data.actions, bpy.data.materials):
        for block in list(coll):
            if block.users == 0:
                coll.remove(block)
    bpy.context.scene.render.fps = FPS


def make_material(name, hex_value, rough=0.6, metal=0.0, emission=0.0):
    mat = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    col = hex_color(hex_value)
    bsdf.inputs["Base Color"].default_value = col
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emission > 0.0:
        bsdf.inputs["Emission Color"].default_value = col
        bsdf.inputs["Emission Strength"].default_value = emission
    return mat


def build_armature():
    data = bpy.data.armatures.new("Humanoid")
    rig = bpy.data.objects.new("Humanoid", data)
    bpy.context.scene.collection.objects.link(rig)
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    for name, parent, head, tail in BONES:
        b = data.edit_bones.new(name)
        b.head, b.tail = head, tail
        if parent:
            b.parent = data.edit_bones[parent]
            b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return rig


def add_part(parts, bone, center, size, mat_index):
    """Queue an axis-aligned box (8 verts / 12 tris) skinned 100% to bone."""
    parts.append((bone, center, size, mat_index))


def build_mesh(rig, parts, materials, name):
    verts, faces, face_mats, groups = [], [], [], {}
    quads = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
    for bone, c, s, mi in parts:
        base = len(verts)
        for dx in (-1, 1):
            for dy in (-1, 1):
                for dz in (-1, 1):
                    verts.append((c[0] + dx * s[0] / 2, c[1] + dy * s[1] / 2, c[2] + dz * s[2] / 2))
        groups.setdefault(bone, []).extend(range(base, base + 8))
        for q in quads:
            faces.append(tuple(base + i for i in q))
            face_mats.append(mi)
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    me.update()
    for m in materials:
        me.materials.append(m)
    for poly, mi in zip(me.polygons, face_mats):
        poly.material_index = mi
        poly.use_smooth = False
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    for bone, idx in groups.items():
        vg = obj.vertex_groups.new(name=bone)
        vg.add(idx, 1.0, "REPLACE")
    obj.parent = rig
    mod = obj.modifiers.new("Armature", "ARMATURE")
    mod.object = rig
    return obj


def standard_parts(bulk=1.0):
    """Body boxes. Material indices: 0 primary, 1 secondary, 2 emblem, 3 extra (lenses/skin)."""
    p = []
    w = bulk
    add_part(p, "Hips", (0, 0, 1.0), (0.34 * w, 0.20 * w, 0.16), 1)
    add_part(p, "Spine", (0, 0, 1.17), (0.32 * w, 0.19 * w, 0.18), 0)
    add_part(p, "Chest", (0, 0, 1.35), (0.42 * w, 0.24 * w, 0.22), 0)
    add_part(p, "Chest", (0, -0.125 * w, 1.36), (0.14, 0.02, 0.12), 2)  # emblem plate
    add_part(p, "Neck", (0, 0, 1.50), (0.10, 0.10, 0.10), 1)
    add_part(p, "Head", (0, 0, 1.67), (0.20, 0.22, 0.25), 0)
    for side, sx in (("L", 1), ("R", -1)):
        add_part(p, "Head", (0.05 * sx, -0.112, 1.69), (0.06, 0.01, 0.04), 3)  # eye/lens
        add_part(p, "UpperArm." + side, (0.33 * sx, 0, 1.42), (0.26, 0.11 * w, 0.11 * w), 0)
        add_part(p, "LowerArm." + side, (0.58 * sx, 0, 1.42), (0.24, 0.09 * w, 0.09 * w), 1)
        add_part(p, "Hand." + side, (0.75 * sx, 0, 1.42), (0.10, 0.06, 0.09), 0)
        add_part(p, "UpperLeg." + side, (0.10 * sx, 0, 0.735), (0.15 * w, 0.15 * w, 0.43), 1)
        add_part(p, "LowerLeg." + side, (0.10 * sx, 0, 0.30), (0.12 * w, 0.12 * w, 0.44), 0)
        add_part(p, "Foot." + side, (0.10 * sx, -0.06, 0.04), (0.11, 0.24, 0.08), 1)
    return p


# ---------------------------------------------------------------- animation
def _key(rig, frame, pose, hips_loc=(0, 0, 0)):
    """pose: {bone: (x_deg, y_deg, z_deg)} Euler rotations; unspecified bones rest."""
    for pb in rig.pose.bones:
        pb.rotation_mode = "XYZ"
        r = pose.get(pb.name, (0, 0, 0))
        pb.rotation_euler = tuple(math.radians(a) for a in r)
        pb.keyframe_insert("rotation_euler", frame=frame)
    hips = rig.pose.bones["Hips"]
    hips.location = hips_loc
    hips.keyframe_insert("location", frame=frame)


def _arms_down(extra=None):
    # Bones point along +-X; rotate around local axes to drop arms near the body.
    p = {"UpperArm.L": (0, 0, -70), "UpperArm.R": (0, 0, 70)}
    if extra:
        p.update(extra)
    return p


def _cycle(rig, length, amp, lean=0.0, bounce=0.0, arm=30.0):
    for i, t in enumerate((0, length / 2, length)):
        s = 1 if i != 1 else -1
        _key(rig, 1 + t, _arms_down({
            "UpperLeg.L": (amp * s, 0, 0), "UpperLeg.R": (-amp * s, 0, 0),
            "LowerLeg.L": (-amp * 0.8 if s < 0 else -10, 0, 0),
            "LowerLeg.R": (-amp * 0.8 if s > 0 else -10, 0, 0),
            "Spine": (lean, 0, 0),
            "UpperArm.L": (0, arm * -s, -70), "UpperArm.R": (0, arm * -s, 70),
            "LowerArm.L": (0, 0, -20), "LowerArm.R": (0, 0, 20),
        }), (0, 0, -bounce))
    mid = 1 + length / 4
    _key(rig, mid, _arms_down({"Spine": (lean, 0, 0)}), (0, 0, bounce))


def _poses(rig, frames):
    for f, pose, loc in frames:
        _key(rig, f, pose, loc)


# KO falls. Pose-bone location is in the Hips rest frame: local +Y = world up, local +Z = world
# -Y (the character faces -Y). Dropping Hips by 0.80 puts the pelvis at ~0.15 m; the whole body
# hangs off Hips, so a +-90 deg tip about X (front/back) or Z (side) lays the torso, head and legs
# flat. Shoulders end ~0.15-0.25 m above the floor, well under the 0.35 m contract limit.
# The armature object (root) never moves, so root Z stays 0.
KO_DROP = -0.80


def _ko_clip(rig, kind):
    D = _arms_down
    if kind == "back":  # hit from the front, falls on its back, knees bent, arms splayed
        mid = D({"Spine": (-25, 0, 0), "Head": (-20, 0, 0), "UpperLeg.L": (35, 0, 0), "LowerLeg.L": (-50, 0, 0),
                 "UpperLeg.R": (20, 0, 0), "LowerLeg.R": (-30, 0, 0), "UpperArm.L": (0, 0, -20), "UpperArm.R": (0, 0, 20)})
        end = {"Hips": (-90, 0, 0), "Spine": (-5, 0, 4), "Head": (-10, 15, 0),
               "UpperArm.L": (0, 30, -5), "LowerArm.L": (0, 0, -25), "UpperArm.R": (0, -20, 10), "LowerArm.R": (0, 0, 40),
               "UpperLeg.L": (25, 0, 6), "LowerLeg.L": (-45, 0, 0), "UpperLeg.R": (-4, 0, -8), "LowerLeg.R": (-8, 0, 0),
               "Foot.L": (20, 0, 0), "Foot.R": (10, 0, 0)}
        frames = [(1, D(), (0, 0, 0)), (10, mid, (0, -0.35, -0.10)),
                  (22, dict(end, Hips=(-80, 0, 0)), (0, KO_DROP + 0.04, -0.35)), (30, end, (0, KO_DROP, -0.40)),
                  (36, end, (0, KO_DROP, -0.40))]
    elif kind == "front":  # hit from behind, pitches forward onto its face
        mid = D({"Spine": (30, 0, 0), "Chest": (15, 0, 0), "UpperLeg.L": (-25, 0, 0), "LowerLeg.L": (-40, 0, 0),
                 "UpperArm.L": (0, 50, -40), "UpperArm.R": (0, -50, 40)})
        end = {"Hips": (90, 0, 0), "Spine": (4, 0, -3), "Head": (-30, 25, 0),
               "UpperArm.L": (0, 60, -20), "LowerArm.L": (0, 0, -60), "UpperArm.R": (0, -10, 55), "LowerArm.R": (0, 0, 20),
               "UpperLeg.L": (-4, 0, 8), "LowerLeg.L": (-35, 0, 0), "UpperLeg.R": (2, 0, -4), "LowerLeg.R": (-6, 0, 0),
               "Foot.L": (-40, 0, 0), "Foot.R": (-50, 0, 0)}
        frames = [(1, D(), (0, 0, 0)), (9, mid, (0, -0.20, 0.15)),
                  (20, dict(end, Hips=(78, 0, 0)), (0, KO_DROP + 0.05, 0.40)), (28, end, (0, KO_DROP, 0.45)),
                  (34, end, (0, KO_DROP, 0.45))]
    elif kind == "side":  # hit from the side, spins and collapses onto its right side
        mid = D({"Spine": (0, 25, -20), "Chest": (0, 15, 0), "UpperLeg.R": (20, 0, 0), "LowerLeg.R": (-60, 0, 0),
                 "UpperArm.L": (0, 0, 30)})
        end = {"Hips": (0, 40, -90), "Spine": (10, 0, -6), "Head": (0, 0, 20),
               "UpperArm.L": (0, 40, -40), "LowerArm.L": (0, 0, -50), "UpperArm.R": (0, 10, 30), "LowerArm.R": (0, 0, 35),
               "UpperLeg.L": (45, 0, 0), "LowerLeg.L": (-70, 0, 0), "UpperLeg.R": (15, 0, 0), "LowerLeg.R": (-25, 0, 0)}
        frames = [(1, D(), (0, 0, 0)), (10, mid, (0, -0.30, 0)),
                  (22, dict(end, Hips=(0, 35, -80)), (0, KO_DROP + 0.05, 0)), (30, end, (0, KO_DROP, 0)),
                  (36, end, (0, KO_DROP, 0))]
    else:  # heavy: launched off its feet, airborne arc, slams down on its back and settles
        air = D({"Hips": (-50, 0, 0), "Spine": (-30, 0, 0), "UpperLeg.L": (60, 0, 0), "LowerLeg.L": (-40, 0, 0),
                 "UpperLeg.R": (75, 0, 0), "LowerLeg.R": (-20, 0, 0), "UpperArm.L": (0, 0, 40), "UpperArm.R": (0, 0, -40)})
        end = {"Hips": (-90, 0, 0), "Spine": (-3, 0, -6), "Head": (-15, -20, 0),
               "UpperArm.L": (0, 10, 30), "LowerArm.L": (0, 0, 50), "UpperArm.R": (0, -35, -10), "LowerArm.R": (0, 0, -30),
               "UpperLeg.L": (15, 0, 10), "LowerLeg.L": (-25, 0, 0), "UpperLeg.R": (40, 0, -5), "LowerLeg.R": (-70, 0, 0)}
        frames = [(1, D(), (0, 0, 0)), (6, D({"Spine": (-20, 0, 0)}), (0, -0.10, -0.15)),
                  (14, air, (0, 0.25, -0.90)), (26, dict(end, Hips=(-100, 0, 0)), (0, KO_DROP + 0.02, -1.60)),
                  (32, dict(end, Hips=(-84, 0, 0)), (0, KO_DROP + 0.08, -1.75)), (40, end, (0, KO_DROP, -1.85)),
                  (46, end, (0, KO_DROP, -1.85))]
    _poses(rig, frames)


def _make_clip(rig, name):
    a = bpy.data.actions.new(name)
    rig.animation_data.action = a
    D = _arms_down
    if name == "idle":
        _poses(rig, [(1, D(), (0, 0, 0)), (30, D({"Chest": (3, 0, 0)}), (0, 0, -0.01)), (60, D(), (0, 0, 0))])
    elif name == "run":
        _cycle(rig, 20, 35, lean=10, bounce=0.03, arm=35)
    elif name == "sprint":
        _cycle(rig, 16, 50, lean=20, bounce=0.05, arm=50)
    elif name == "jump":
        _poses(rig, [(1, D({"UpperLeg.L": (-20, 0, 0), "UpperLeg.R": (-20, 0, 0), "LowerLeg.L": (40, 0, 0), "LowerLeg.R": (40, 0, 0)}), (0, 0, -0.15)),
                     (8, {"UpperArm.L": (0, 0, 40), "UpperArm.R": (0, 0, -40)}, (0, 0, 0.05)),
                     (16, D({"UpperLeg.L": (40, 0, 0), "LowerLeg.L": (-60, 0, 0)}), (0, 0, 0))])
    elif name == "fall":
        _poses(rig, [(1, {"UpperArm.L": (0, 0, 20), "UpperArm.R": (0, 0, -20), "UpperLeg.L": (20, 0, 0), "LowerLeg.L": (-30, 0, 0)}, (0, 0, 0)),
                     (20, {"UpperArm.L": (0, 0, 30), "UpperArm.R": (0, 0, -30), "UpperLeg.R": (20, 0, 0), "LowerLeg.R": (-30, 0, 0)}, (0, 0, 0))])
    elif name == "swing":
        up = {"UpperArm.R": (0, 0, -80), "LowerArm.R": (0, 0, 0)}
        _poses(rig, [(1, dict(up, **{"UpperLeg.L": (40, 0, 0), "UpperLeg.R": (40, 0, 0), "LowerLeg.L": (-70, 0, 0), "LowerLeg.R": (-70, 0, 0), "UpperArm.L": (0, 0, -40)}), (0, 0, 0)),
                     (20, dict(up, **{"UpperLeg.L": (-20, 0, 0), "UpperLeg.R": (-10, 0, 0), "Spine": (-15, 0, 0), "UpperArm.L": (0, 0, -60)}), (0, 0, 0)),
                     (40, dict(up, **{"UpperLeg.L": (40, 0, 0), "UpperLeg.R": (40, 0, 0), "LowerLeg.L": (-70, 0, 0), "LowerLeg.R": (-70, 0, 0), "UpperArm.L": (0, 0, -40)}), (0, 0, 0))])
    elif name == "zip":
        p = {"UpperArm.L": (0, -80, 0), "UpperArm.R": (0, 80, 0), "Spine": (20, 0, 0), "UpperLeg.L": (30, 0, 0), "LowerLeg.L": (-60, 0, 0)}
        _poses(rig, [(1, p, (0, 0, 0)), (10, dict(p, Spine=(30, 0, 0)), (0, 0, 0))])
    elif name == "wall_run":
        _cycle(rig, 18, 45, lean=-10, bounce=0.02, arm=40)
    elif name == "land_hero":
        _poses(rig, [(1, D(), (0, 0, 0)),
                     (6, {"Spine": (40, 0, 0), "UpperLeg.L": (90, 0, 0), "LowerLeg.L": (-100, 0, 0), "UpperLeg.R": (10, 0, 0), "LowerLeg.R": (-110, 0, 0), "UpperArm.R": (0, 60, 80), "UpperArm.L": (0, 0, 20)}, (0, 0, -0.45)),
                     (30, {"Spine": (40, 0, 0), "UpperLeg.L": (90, 0, 0), "LowerLeg.L": (-100, 0, 0), "UpperLeg.R": (10, 0, 0), "LowerLeg.R": (-110, 0, 0), "UpperArm.R": (0, 60, 80), "UpperArm.L": (0, 0, 20)}, (0, 0, -0.45)),
                     (45, D(), (0, 0, 0))])
    elif name == "roll":
        tuck = D({"UpperLeg.L": (110, 0, 0), "UpperLeg.R": (110, 0, 0), "LowerLeg.L": (-120, 0, 0), "LowerLeg.R": (-120, 0, 0), "Chest": (40, 0, 0)})
        _poses(rig, [(1, dict(tuck, Hips=(0, 0, 0)), (0, 0, -0.4)), (8, dict(tuck, Hips=(180, 0, 0)), (0, 0, -0.4)),
                     (16, dict(tuck, Hips=(360, 0, 0)), (0, 0, -0.4)), (20, D(), (0, 0, 0))])
    elif name in ("punch_1", "punch_2", "punch_3"):
        side, sx = {"punch_1": ("R", 1), "punch_2": ("L", -1), "punch_3": ("R", 1)}[name]
        strike = D({"UpperArm." + side: (0, 80 * sx, 0), "LowerArm." + side: (0, 0, 0), "Chest": (0, 0, 25 * sx)})
        if name == "punch_3":
            strike.update({"UpperLeg.L": (70, 0, 0), "Spine": (-10, 0, 0)})
        _poses(rig, [(1, D({"Chest": (0, 0, -15 * sx)}), (0, 0, 0)), (5, strike, (0, 0, 0)), (14, D(), (0, 0, 0))])
    elif name == "dodge":
        _poses(rig, [(1, D(), (0, 0, 0)), (6, D({"Spine": (-20, 0, 0), "Chest": (0, 30, 0), "UpperLeg.L": (30, 0, 0)}), (0.3, 0, -0.15)), (14, D(), (0, 0, 0))])
    elif name == "finisher":
        _poses(rig, [(1, D(), (0, 0, 0)),
                     (10, {"UpperArm.L": (0, 0, 60), "UpperArm.R": (0, 0, -60), "Spine": (-20, 0, 0)}, (0, 0, 0.3)),
                     (18, {"UpperArm.L": (0, -90, -10), "UpperArm.R": (0, 90, 10), "Spine": (35, 0, 0), "UpperLeg.L": (60, 0, 0), "LowerLeg.L": (-90, 0, 0)}, (0, 0, -0.3)),
                     (36, D(), (0, 0, 0))])
    elif name == "hit":
        _poses(rig, [(1, D(), (0, 0, 0)), (4, D({"Spine": (-20, 0, 0), "Head": (-25, 0, 0)}), (0, 0.08, 0)), (14, D(), (0, 0, 0))])
    elif name == "death" or name.startswith("ko_"):
        _ko_clip(rig, "back" if name == "death" else name[3:])
    loop = name in ("idle", "run", "sprint", "fall", "swing", "zip", "wall_run")
    if loop:
        for fc in getattr(a, "fcurves", []):
            fc.modifiers.new("CYCLES")
    track = rig.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, a)
    strip.name = name
    a.use_fake_user = True
    rig.animation_data.action = None


def build_clips(rig, extra=()):
    rig.animation_data_create()
    for c in list(CLIPS) + list(extra):
        _make_clip(rig, c)
    for pb in rig.pose.bones:  # back to rest pose for the exported bind
        pb.rotation_euler = (0, 0, 0)
        pb.location = (0, 0, 0)


def export(root, filename):
    out_dir = os.path.join(root, "assets", "models")
    os.makedirs(out_dir, exist_ok=True)
    path = os.path.join(out_dir, filename)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_skins=True,
        export_yup=True,
        export_apply=False,
    )
    print("[build] exported", path)
    return path


def build(script_file, filename, model_name, colors, bulk=1.0, extra_hex="#F2F2F2", extra_clips=()):
    """colors: dict primary/secondary/emblem -> '#RRGGBB'."""
    reset_scene()
    mats = [
        make_material("Suit_Primary", colors["primary"]),
        make_material("Suit_Secondary", colors["secondary"]),
        make_material("Suit_Emblem", colors["emblem"], rough=0.4),
        make_material("Lens", extra_hex, rough=0.2, emission=0.5),
    ]
    rig = build_armature()
    mesh = build_mesh(rig, standard_parts(bulk), mats, model_name)
    build_clips(rig, extra_clips)
    tris = sum(len(p.vertices) - 2 for p in mesh.data.polygons)
    print("[build] %s: %d tris, %d bones, %d clips" % (model_name, tris, len(BONES), len(CLIPS) + len(extra_clips)))
    return export(project_root(script_file), filename)
