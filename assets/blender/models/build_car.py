"""Build the low-poly traffic car and export assets/models/car.glb.

Run: blender -b --python assets/blender/models/build_car.py
Blender axes: front = +Y, up = +Z, right = +X. glTF export with export_yup=True
maps Blender +Y to glTF -Z, so in Godot the car faces -Z (Node3D forward).
Size 4.4 (length) x 1.9 (width) x 1.5 (height) m, wheel bottoms at Z=0.
Only bpy + stdlib. Wheel objects have their origin on the axle and spin around local X.
"""
import math
import os

import bmesh
import bpy

LENGTH = 4.4
WIDTH = 1.9
HEIGHT = 1.5
WHEEL_R = 0.38
WHEEL_W = 0.3
WHEEL_SEG = 20
AXLE_Y = 1.4
ARCH_R = WHEEL_R + 0.06
ARCH_SEG = 8


def _project_root() -> str:
    here = os.path.dirname(os.path.abspath(globals().get("__file__", "") or ""))
    root = os.path.normpath(os.path.join(here, "..", "..", ".."))
    if not os.path.exists(os.path.join(root, "project.godot")) and bpy.data.filepath:
        root = os.path.dirname(bpy.data.filepath)
    return root


def _car_collection():
    c = bpy.data.collections.get("Kit_car")
    if c is None:
        c = bpy.data.collections.new("Kit_car")
    if c.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(c)
    return c


def clear_scene() -> None:
    """Clear only the car's own 'Kit_car' collection; other objects in the .blend stay."""
    for ob in list(_car_collection().objects):
        me = ob.data if ob.type == "MESH" else None
        bpy.data.objects.remove(ob, do_unlink=True)
        if me is not None and me.users == 0:
            bpy.data.meshes.remove(me)


def make_material(name, rgb, rough=0.5, metal=0.0, emission=None, strength=0.0, alpha=1.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if emission is not None:
        bsdf.inputs["Emission Color"].default_value = (emission[0], emission[1], emission[2], 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        mat.blend_method = "BLEND"
    return mat


def make_object(name, verts, faces, mat, location=(0.0, 0.0, 0.0)):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    mesh.materials.append(mat)
    ob = bpy.data.objects.new(name, mesh)
    ob.location = location
    _car_collection().objects.link(ob)
    return ob


def prism(x0, x1, y0, y1, z0, z1, top_inset_x=0.0, top_inset_y0=0.0, top_inset_y1=0.0):
    """8-vertex box; the top face may be inset (tapered cabin). 6 quads = 12 tris."""
    verts = [
        (x0, y0, z0), (x1, y0, z0), (x1, y1, z0), (x0, y1, z0),
        (x0 + top_inset_x, y0 + top_inset_y0, z1), (x1 - top_inset_x, y0 + top_inset_y0, z1),
        (x1 - top_inset_x, y1 - top_inset_y1, z1), (x0 + top_inset_x, y1 - top_inset_y1, z1),
    ]
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    return verts, faces


def merge(parts):
    verts, faces = [], []
    for v, f in parts:
        base = len(verts)
        verts.extend(v)
        faces.extend(tuple(i + base for i in face) for face in f)
    return verts, faces


def add_mat(ob, mat):
    ob.data.materials.append(mat)
    return len(ob.data.materials) - 1


def bevel(ob, width, segments=2):
    """Bevel modifier limited by angle so only hard panel edges get rounded."""
    mod = ob.modifiers.new('Bevel', 'BEVEL')
    mod.width = width
    mod.segments = segments
    mod.limit_method = 'ANGLE'
    mod.angle_limit = math.radians(30.0)
    mod.harden_normals = False
    return mod


def side_profile():
    """Body side silhouette in (y, z), CCW, with semicircular wheel arches cut into the sill."""
    hy = LENGTH * 0.5
    pts = [(-hy, 0.30)]
    for cy in (-AXLE_Y, AXLE_Y):
        pts.append((cy - ARCH_R, 0.30))
        for i in range(1, ARCH_SEG):
            a = math.pi - math.pi * i / ARCH_SEG
            pts.append((cy + math.cos(a) * ARCH_R, WHEEL_R + math.sin(a) * ARCH_R))
        pts.append((cy + ARCH_R, 0.30))
    pts += [(hy, 0.30), (hy, 0.62), (hy - 0.08, 0.80), (hy - 0.25, 0.86),
            (0.85, 0.95), (-1.25, 0.97), (-hy + 0.12, 0.90), (-hy, 0.78)]
    return pts


def extrude_profile(pts, x0, x1, taper=0.0, taper_z=0.8):
    """Extrude a (y, z) polygon along X; verts above taper_z are pulled in by taper (tumblehome)."""
    n = len(pts)
    verts = []
    for x in (x0, x1):
        for y, z in pts:
            t = taper if z > taper_z else 0.0
            verts.append((x + t if x < 0 else x - t, y, z))
    faces = [tuple(range(n - 1, -1, -1)), tuple(range(n, 2 * n))]
    for i in range(n):
        j = (i + 1) % n
        faces.append((i, j, n + j, n + i))
    return verts, faces


def ring(x, r, seg):
    return [(x, math.cos(2 * math.pi * i / seg) * r, math.sin(2 * math.pi * i / seg) * r) for i in range(seg)]


def wheel_parts():
    """Tire (rounded tread) + recessed rim with hub, axle along X, origin at the axle.
    Returns verts, faces, per-face material slot (0 tire, 1 rim). Outer side is +X; mirrored for left wheels."""
    hw = WHEEL_W * 0.5
    s = WHEEL_SEG
    profile = [(-hw, WHEEL_R * 0.78, 0), (-hw * 0.75, WHEEL_R, 0), (hw * 0.75, WHEEL_R, 0),
               (hw, WHEEL_R * 0.78, 0), (hw * 0.85, WHEEL_R * 0.66, 1), (hw * 0.95, WHEEL_R * 0.25, 1),
               (hw * 1.05, WHEEL_R * 0.12, 1)]
    verts, faces, mats = [], [], []
    for x, r, _ in profile:
        verts += ring(x, r, s)
    for k in range(len(profile) - 1):
        for i in range(s):
            j = (i + 1) % s
            a, b = k * s, (k + 1) * s
            faces.append((a + i, a + j, b + j, b + i))
            mats.append(profile[k + 1][2] if k >= 3 else 0)
    last = (len(profile) - 1) * s
    faces.append(tuple(range(last, last + s)))  # hub cap
    mats.append(1)
    faces.append(tuple(range(s - 1, -1, -1)))  # inner sidewall cap
    mats.append(0)
    # Five spokes: thin boxes from hub to rim lip, slightly proud of the rim face.
    for k in range(5):
        a = 2 * math.pi * k / 5
        ca, sa = math.cos(a), math.sin(a)
        px, py = -sa * 0.03, ca * 0.03
        r0, r1 = WHEEL_R * 0.14, WHEEL_R * 0.64
        b = len(verts)
        for x in (hw * 0.9, hw * 1.02):
            verts += [(x, ca * r0 - px * 0 + -sa * 0.03, sa * r0 + ca * 0.03),
                      (x, ca * r0 + sa * 0.03, sa * r0 - ca * 0.03),
                      (x, ca * r1 + sa * 0.03, sa * r1 - ca * 0.03),
                      (x, ca * r1 - sa * 0.03, sa * r1 + ca * 0.03)]
        for f in ((4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)):
            faces.append(tuple(b + i for i in f))
            mats.append(1)
    return verts, faces, mats


def finish(ob, smooth=True):
    """Apply modifiers, smooth shade, mark edges sharper than 30 degrees."""
    bpy.context.view_layer.objects.active = ob
    for o in bpy.context.selected_objects:
        o.select_set(False)
    ob.select_set(True)
    for mod in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=mod.name)
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for e in bm.edges:
        e.smooth = not (len(e.link_faces) == 2 and e.calc_face_angle(0.0) > math.radians(30.0))
    for f in bm.faces:
        f.smooth = smooth
    bm.normal_update()
    bm.to_mesh(ob.data)
    bm.free()
    if hasattr(ob.data, 'use_auto_smooth'):
        ob.data.use_auto_smooth = True
        ob.data.auto_smooth_angle = math.radians(30.0)


def build() -> None:
    clear_scene()
    paint = make_material('Car_Paint', (0.8, 0.8, 0.8), rough=0.35, metal=0.4)
    glass = make_material('Car_Glass', (0.04, 0.06, 0.08), rough=0.1, metal=0.2, alpha=0.6)
    tire = make_material('Car_Tire', (0.03, 0.03, 0.03), rough=0.9)
    rim = make_material('Car_Rim', (0.75, 0.76, 0.78), rough=0.3, metal=0.9)
    trim = make_material('Car_Trim', (0.12, 0.12, 0.13), rough=0.6)
    head = make_material('Car_Headlight', (1.0, 0.97, 0.9), emission=(1.0, 0.95, 0.85), strength=3.0)
    brake = make_material('Car_Brakelight', (0.7, 0.03, 0.03), emission=(1.0, 0.05, 0.03), strength=1.0)

    hx = WIDTH * 0.5
    hy = LENGTH * 0.5

    # Body: extruded side profile with arches, tumblehome above the belt line, bevelled panels.
    bv, bf = extrude_profile(side_profile(), -hx + 0.02, hx - 0.02, taper=0.06)
    body = make_object('Body', bv, bf, paint)
    bevel(body, 0.035, 2)
    finish(body)
    # Panel seams (doors, hood, trunk): thin trim strips just proud of the paint.
    seams = []
    for y in (0.85, -0.15, -1.15):
        for x in (-hx + 0.065, hx - 0.065):
            sx = 0.004 if x > 0 else -0.004
            seams.append(prism(min(x, x + sx), max(x, x + sx), y - 0.006, y + 0.006, 0.34, 0.9))
    seams.append(prism(-hx + 0.2, hx - 0.2, 0.86, 0.872, 0.95, 0.957))
    seams.append(prism(-hx + 0.2, hx - 0.2, -1.32, -1.308, 0.97, 0.977))
    sv, sf = merge(seams)
    seam_ob = make_object('Body_Seams', sv, sf, trim)

    # Cabin: greenhouse prism with sloped screens, Windows sit slightly proud and inset from edges (pillars).
    cv, cf = prism(-hx + 0.16, hx - 0.16, -1.25, 0.85, 0.95, HEIGHT, 0.12, 0.45, 0.65)
    cabin = make_object('Cabin', cv, cf, paint)
    bevel(cabin, 0.03, 2)
    finish(cabin)

    win = []
    zb, zt = 1.0, HEIGHT - 0.06
    cx = hx - 0.16
    # Side windows (two panes per side split by the B pillar), following the side slope.
    for sgn in (-1, 1):
        for y0, y1 in ((-0.75, -0.2), (-0.1, 0.25)):
            xb = sgn * (cx + 0.006)
            xt = sgn * (cx - 0.12 + 0.006)
            win.append(([(xb, y0, zb), (xb, y1, zb), (xt, y1, zt), (xt, y0, zt)],
                        [(0, 1, 2, 3) if sgn > 0 else (3, 2, 1, 0)]))
    # Windscreen (front, +Y) and rear screen.
    yf0, yf1 = 0.85 - 0.1, 0.85 - 0.65 + 0.06
    win.append(([(-cx + 0.12, yf0 + 0.008, zb), (cx - 0.12, yf0 + 0.008, zb),
                 (cx - 0.2, yf1 + 0.008, zt), (-cx + 0.2, yf1 + 0.008, zt)], [(0, 1, 2, 3)]))
    yr0, yr1 = -1.25 + 0.08, -1.25 + 0.45 - 0.05
    win.append(([(-cx + 0.12, yr0 - 0.008, zb), (cx - 0.12, yr0 - 0.008, zb),
                 (cx - 0.2, yr1 - 0.008, zt), (-cx + 0.2, yr1 - 0.008, zt)], [(3, 2, 1, 0)]))
    wv, wf = merge(win)
    windows = make_object('Windows', wv, wf, glass)
    sol = windows.modifiers.new('Solidify', 'SOLIDIFY')
    sol.thickness = 0.01
    finish(windows, smooth=False)

    # Bumpers: separate trim pieces wrapping the corners.
    bmp = merge([prism(-hx + 0.03, hx - 0.03, hy - 0.08, hy + 0.02, 0.28, 0.48),
                 prism(-hx + 0.03, hx - 0.03, -hy - 0.02, -hy + 0.08, 0.28, 0.48)])
    bumpers = make_object('Bumpers', bmp[0], bmp[1], trim)
    bevel(bumpers, 0.03, 2)
    finish(bumpers)

    # Grille: frame plus horizontal slats between the headlights.
    gl = [prism(-0.42, 0.42, hy - 0.01, hy + 0.012, 0.5, 0.52), prism(-0.42, 0.42, hy - 0.01, hy + 0.012, 0.68, 0.7)]
    for z in (0.555, 0.605, 0.655):
        gl.append(prism(-0.4, 0.4, hy - 0.01, hy + 0.02, z, z + 0.018))
    gv, gf = merge(gl)
    make_object('Grille', gv, gf, trim)

    # Mirrors: paint housing + trim arm on each door.
    # Housings stay within 0.025 m of the body side so total width is <= 1.95 m.
    mv, mf = merge([prism(-hx - 0.025, -hx + 0.08, 0.55, 0.68, 1.0, 1.12),
                    prism(hx - 0.08, hx + 0.025, 0.55, 0.68, 1.0, 1.12)])
    mirrors = make_object('Mirrors', mv, mf, paint)
    t_slot = add_mat(mirrors, trim)
    av, af = merge([prism(s * (hx - 0.16) - 0.0 if s > 0 else s * hx + 0.06, s * hx - 0.06 if s > 0 else s * (hx - 0.16),
                          0.6, 0.64, 0.98, 1.02) for s in (-1, 1)])
    me = mirrors.data
    base = len(me.vertices)
    bm = bmesh.new()
    bm.from_mesh(me)
    nv = [bm.verts.new(v) for v in av]
    for f in af:
        face = bm.faces.new([nv[i] for i in f])
        face.material_index = t_slot
    bm.to_mesh(me)
    bm.free()
    bevel(mirrors, 0.012, 1)
    finish(mirrors)

    # Lights: bevelled lenses set into the nose and tail.
    hl = merge([prism(-0.84, -0.46, hy - 0.06, hy + 0.01, 0.58, 0.72),
                prism(0.46, 0.84, hy - 0.06, hy + 0.01, 0.58, 0.72)])
    headlights = make_object('Headlights', hl[0], hl[1], head)
    bevel(headlights, 0.015, 1)
    finish(headlights)
    tl = merge([prism(-0.86, -0.45, -hy - 0.012, -hy + 0.06, 0.66, 0.8),
                prism(0.45, 0.86, -hy - 0.012, -hy + 0.06, 0.66, 0.8)])
    brakelights = make_object('Brakelights', tl[0], tl[1], brake)
    bevel(brakelights, 0.015, 1)
    finish(brakelights)

    # Wheels: tire + rim in one object, origin on the axle, rolling axis X.
    wv, wf, wm = wheel_parts()
    for name, x, y in (('Wheel_FL', -hx + 0.17, AXLE_Y), ('Wheel_FR', hx - 0.17, AXLE_Y),
                       ('Wheel_RL', -hx + 0.17, -AXLE_Y), ('Wheel_RR', hx - 0.17, -AXLE_Y)):
        verts = wv if x > 0 else [(-v[0], v[1], v[2]) for v in wv]
        faces = wf if x > 0 else [tuple(reversed(f)) for f in wf]
        ob = make_object(name, verts, faces, tire, (x, y, WHEEL_R))
        add_mat(ob, rim)
        for poly, m in zip(ob.data.polygons, wm):
            poly.material_index = m
        finish(ob)

    # Seams are part of the Body object (trim slot) so the contract object list stays exact.
    s_slot = add_mat(body, trim)
    for poly in seam_ob.data.polygons:
        poly.material_index = 0
    seam_ob.data.materials.clear()
    seam_ob.data.materials.append(paint)
    seam_ob.data.materials.append(trim)
    for poly in seam_ob.data.polygons:
        poly.material_index = s_slot
    for o in bpy.context.selected_objects:
        o.select_set(False)
    seam_ob.select_set(True)
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.join()

    bpy.context.view_layer.update()
    tris = 0
    for ob in bpy.data.objects:
        if ob.type == 'MESH':
            tris += sum(len(p.vertices) - 2 for p in ob.data.polygons)
    names = sorted(ob.name for ob in bpy.data.objects)
    print('[build_car] objects:', names)
    print('[build_car] triangles:', tris)
    assert 1500 <= tris <= 4000, 'triangle count %d outside 1500..4000' % tris

    out = os.path.join(_project_root(), 'assets', 'models', 'car.glb')
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=out, export_format='GLB', export_yup=True, export_apply=True,
        export_animations=False, export_materials='EXPORT',
    )
    print('[build_car] exported', out)


build()
