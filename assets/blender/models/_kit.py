"""Shared helpers for the iteration-2 prop / road / park generators (Blender 4.x, bpy + bmesh).

Every generator <name>.py does:
    GLB_PATH = "res://assets/models/<group>/<name>.glb"
    def build(): ...  -> list of variant objects, or {"": [...], "_lod1": [...], "_bb": [...]}
    if __name__ == "__main__": _kit.run(build, GLB_PATH)

Conventions
- 1 unit = 1 m, Blender Z up, exported with export_yup=True (Blender +Y -> Godot -Z).
- Every variant is ONE mesh object named <name>_v1, <name>_v2 ... with its pivot at the ground
  centre (mesh data is centred on the object origin). Objects are spread along X only so the
  Blender screenshot shows all variants; Godot code should use the mesh, not the node offset.
- At most 2 materials per glb. Each material is named M_<model>_<part> (lower case) and has a
  baked procedural PNG (assets/blender/models/textures/<model>/<material>.png) wired into
  Principled BSDF Base Color, so the glTF exporter writes baseColorTexture and embeds the PNG.
- Colours passed to box()/cyl()/... are NOT vertex colours any more (Godot ignored COLOR_0):
  every distinct colour of a material gets a cell of an 8x8 atlas in that material's texture,
  and the faces get UVs inside their colour's cell. The pattern (metal, concrete, wood, bark,
  leaves, plastic, paint) is chosen from the part name / metallic value.
- Suffixes: generator names starting with Emit_ -> M_<model>_<part>_emissive; glass / water ->
  _glass; road markings -> _paint (exempt from the near-white rule).
"""
import math
import os
import random

import bpy
import bmesh
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(globals().get("__file__", "") or ""))
if not os.path.exists(os.path.join(HERE, "_kit.py")) and bpy.data.filepath:
    HERE = os.path.join(os.path.dirname(bpy.data.filepath), "assets", "blender", "models")
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
TEX_DIR = os.path.join(HERE, "textures")

PROP_TRIS = (150, 2000)
TREE_LIMITS = {"": (150, 6000), "_lod1": (60, 2000), "_bb": (2, 64)}

TEX_SIZE = 256
GRID = 8                      # atlas cells per side -> 64 colours per material
CELL = TEX_SIZE // GRID       # 32 px
INSET = 3.0 / TEX_SIZE        # keep UVs away from cell borders (mip bleeding)
PAINT_NAMES = ("road_paint", "crosswalk", "marking")
GLASS_NAMES = ("glass", "water")


# ------------------------------------------------------------------ colours / materials
def rgb(h):
    """'#RRGGBB' (sRGB) -> linear RGBA tuple."""
    h = h.lstrip("#")
    s = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in s]
    return (lin[0], lin[1], lin[2], 1.0)


def to_srgb(c):
    return tuple((v * 12.92 if v <= 0.0031308 else 1.055 * (v ** (1 / 2.4)) - 0.055) for v in c[:3])


_MODEL = "kit"   # set by reset(); prefixes every material name
_ATLAS = {}      # material name -> {"cols": [srgb tuples], "kind": str, "image": bpy image}


def part_name(name):
    """Generator part name -> contract material name M_<model>_<part>[_suffix]."""
    p = name.lower()
    suffix = ""
    if p.startswith("emit_"):
        p, suffix = p[5:], "_emissive"
    elif any(g in p for g in GLASS_NAMES):
        suffix = "_glass"
    elif any(k in p for k in PAINT_NAMES):
        suffix = "_paint"
    for s in ("_emissive", "_glass", "_paint"):
        if suffix == s and p.endswith(s):
            p = p[:-len(s)]
    return "M_%s_%s%s" % (_MODEL, p, suffix)


def _kind(part, metal):
    p = part.lower()
    for kind, keys in (("leaves", ("leaves", "moss", "hedge")), ("bark", ("bark",)),
                       ("wood", ("wood", "deck", "table_wood")),
                       ("concrete", ("concrete", "stone", "granite", "rock", "wall", "soil",
                                     "asphalt", "tactile", "void")),
                       ("glass", GLASS_NAMES), ("paint_road", PAINT_NAMES)):
        if any(k in p for k in keys):
            return kind
    if metal >= 0.45 or "iron" in p or "steel" in p or "metal" in p:
        return "metal"
    if "plastic" in p or "cone" in p or "band" in p or "face" in p or "panel" in p:
        return "plastic"
    return "paint"


def mat(name, rough=0.6, metal=0.0, emit=0.0, base="#FFFFFF"):
    """Principled material M_<model>_<part>; Base Color = baked atlas texture (times `base`)."""
    mname = part_name(name)
    m = bpy.data.materials.get(mname) or bpy.data.materials.new(mname)
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        if n.type not in ("BSDF_PRINCIPLED", "OUTPUT_MATERIAL"):
            nt.nodes.remove(n)
    bsdf = nt.nodes.get("Principled BSDF") or next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    img = bpy.data.images.get(mname)
    if img is None or tuple(img.size) != (TEX_SIZE, TEX_SIZE):
        if img is not None:
            bpy.data.images.remove(img)
        img = bpy.data.images.new(mname, TEX_SIZE, TEX_SIZE, alpha=False)
    tex = nt.nodes.new("ShaderNodeTexImage")
    tex.image = img
    tex.interpolation = "Linear"
    color_out = tex.outputs["Color"]
    if base.upper().lstrip("#") != "FFFFFF":
        mix = nt.nodes.new("ShaderNodeMix")   # exporter bakes nothing here; kept for Blender view
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        mix.inputs[7].default_value = rgb(base)
        nt.links.new(color_out, mix.inputs[6])
        color_out = mix.outputs[2]
    nt.links.new(color_out, bsdf.inputs["Base Color"])
    if emit > 0.0 or mname.endswith("_emissive"):
        sock = bsdf.inputs.get("Emission Color") or bsdf.inputs.get("Emission")
        nt.links.new(tex.outputs["Color"], sock)
        bsdf.inputs["Emission Strength"].default_value = emit if emit > 0 else 2.0
    _ATLAS[mname] = {"cols": [], "kind": _kind(name, metal), "image": img}
    return m


def _cell(mname, c):
    """Atlas cell index of colour c (linear RGBA) in material mname; merges near colours when full."""
    a = _ATLAS[mname]
    s = to_srgb(c)
    best, bd = 0, 9.0
    for i, q in enumerate(a["cols"]):
        d = sum((x - y) ** 2 for x, y in zip(s, q))
        if d < 1e-6:
            return i
        if d < bd:
            best, bd = i, d
    if len(a["cols"]) < GRID * GRID:
        a["cols"].append(s)
        return len(a["cols"]) - 1
    return best


# ------------------------------------------------------------------ procedural texture bake
def _hash(x, y, seed):
    n = (x * 374761393 + y * 668265263 + seed * 2147483647) & 0xFFFFFFFF
    n = ((n ^ (n >> 13)) * 1274126177) & 0xFFFFFFFF
    return ((n ^ (n >> 16)) & 0xFFFF) / 65535.0


def _vnoise(x, y, scale, seed):
    fx, fy = x / scale, y / scale
    ix, iy = int(math.floor(fx)), int(math.floor(fy))
    tx, ty = fx - ix, fy - iy
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a, b = _hash(ix, iy, seed), _hash(ix + 1, iy, seed)
    c, d = _hash(ix, iy + 1, seed), _hash(ix + 1, iy + 1, seed)
    return (a + (b - a) * tx) + ((c + (d - c) * tx) - (a + (b - a) * tx)) * ty


def _shade(kind, x, y, seed):
    """Brightness multiplier (~0.7..1.1) of the procedural pattern at pixel (x, y)."""
    r = _hash(x, y, seed + 7)
    if kind == "metal":       # brushed horizontal streaks + light scratches
        return 0.82 + 0.14 * _vnoise(x * 0.15, y, 1.5, seed) + 0.06 * r
    if kind == "concrete":    # aggregate speckle + stains
        return 0.74 + 0.16 * _vnoise(x, y, 9, seed) + 0.1 * _vnoise(x, y, 2, seed + 3) + 0.06 * (r > 0.93)
    if kind == "wood":        # grain bands along U
        g = math.sin((y + 6 * _vnoise(x, y, 14, seed)) * 0.9)
        return 0.78 + 0.12 * g + 0.08 * _vnoise(x * 0.2, y, 3, seed + 1)
    if kind == "bark":        # vertical furrows
        return 0.66 + 0.26 * _vnoise(x, y * 0.25, 2.5, seed) + 0.08 * r
    if kind == "leaves":      # blotchy leaf clusters
        return 0.68 + 0.24 * _vnoise(x, y, 4, seed) + 0.12 * (r - 0.5)
    if kind == "glass":       # faint reflection gradient
        return 0.85 + 0.15 * ((x + y) % CELL) / CELL
    if kind == "paint_road":  # worn paint, asphalt showing through
        return 0.86 + 0.1 * _vnoise(x, y, 6, seed) - 0.12 * (r > 0.95)
    if kind == "plastic":
        return 0.88 + 0.08 * _vnoise(x, y, 5, seed) + 0.03 * r
    return 0.84 + 0.08 * _vnoise(x, y, 12, seed) + 0.04 * r   # painted metal / car paint


def bake(mname):
    """Fill the material's image from its colour atlas and save the PNG."""
    a = _ATLAS[mname]
    cols = a["cols"] or [(0.5, 0.5, 0.5)]
    seed = sum(ord(ch) for ch in mname)
    px = [0.0] * (TEX_SIZE * TEX_SIZE * 4)
    for y in range(TEX_SIZE):
        cy = y // CELL
        for x in range(TEX_SIZE):
            i = cy * GRID + x // CELL
            base = cols[i] if i < len(cols) else cols[i % len(cols)]
            k = _shade(a["kind"], x, y, seed)
            o = (y * TEX_SIZE + x) * 4
            px[o] = min(1.0, base[0] * k)
            px[o + 1] = min(1.0, base[1] * k)
            px[o + 2] = min(1.0, base[2] * k)
            px[o + 3] = 1.0
    # Contract: average colour must not be near-white (some sRGB channel <= 0.85) unless exempt.
    if not mname.endswith(("_paint", "_glass", "_emissive")):
        n = TEX_SIZE * TEX_SIZE
        low = min(sum(px[c::4]) / n for c in range(3))
        if low > 0.8:
            k = 0.8 / low
            for o in range(0, len(px), 4):
                px[o] *= k
                px[o + 1] *= k
                px[o + 2] *= k
    img = a["image"]
    img.colorspace_settings.name = "sRGB"
    img.pixels[:] = px
    d = os.path.join(TEX_DIR, _MODEL)
    os.makedirs(d, exist_ok=True)
    img.filepath_raw = os.path.join(d, mname + ".png")
    img.file_format = "PNG"
    img.save()
    img.pack()   # make sure the exporter embeds the baked pixels
    print("[kit] texture", img.filepath_raw, "colours=%d kind=%s" % (len(a["cols"]), a["kind"]))


_KIT_COLL = None  # named collection of the model currently being built


def _kit_collection(name):
    """Return (creating if needed) the collection 'Kit_<name>' under the scene root."""
    cname = "Kit_" + name
    c = bpy.data.collections.get(cname)
    if c is None:
        c = bpy.data.collections.new(cname)
    if c.name not in bpy.context.scene.collection.children:
        bpy.context.scene.collection.children.link(c)
    return c


def reset(name="kit"):
    """Clear ONLY this model's own 'Kit_<name>' collection. Never touches other objects
    in the open .blend (hero, enemy, car, other props stay intact)."""
    global _KIT_COLL, _MODEL
    _MODEL = name
    _KIT_COLL = _kit_collection(name)
    for o in list(_KIT_COLL.objects):
        me = o.data if o.type == "MESH" else None
        bpy.data.objects.remove(o, do_unlink=True)
        if me is not None and me.users == 0:
            bpy.data.meshes.remove(me)


# ------------------------------------------------------------------ geometry builder
def _rot(r):
    return Euler(tuple(math.radians(a) for a in r), "XYZ").to_matrix().to_4x4()


class Builder:
    """Accumulates beveled parts into one bmesh, then makes a single mesh object."""

    def __init__(self, name, mats):
        assert 1 <= len(mats) <= 2, "at most 2 materials"
        self.name, self.mats = name, mats
        self.bm = bmesh.new()
        self.uv = self.bm.loops.layers.uv.new("UVMap")

    # --- internal
    def _tag(self, before, m, col, smooth, bevel, edges_only_sharp=False):
        new_faces = [f for f in self.bm.faces if f not in before]
        if bevel > 0.0 and new_faces:
            edges = {e for f in new_faces for e in f.edges}
            if edges_only_sharp:
                edges = {e for e in edges if e.calc_face_angle(0.0) > math.radians(50)}
            if edges:
                bmesh.ops.bevel(self.bm, geom=list(edges), offset=bevel, offset_type="OFFSET",
                                segments=1, profile=0.5, affect="EDGES", clamp_overlap=True)
            new_faces = [f for f in self.bm.faces if f not in before]
        c = rgb(col) if isinstance(col, str) else col
        mname = self.mats[min(m, len(self.mats) - 1)].name
        idx = _cell(mname, c) if mname in _ATLAS else 0
        u0 = (idx % GRID) / GRID + INSET
        v0 = (idx // GRID) / GRID + INSET   # bake(): pixel row 0 = bottom = V 0, cell row = idx // GRID
        span = 1.0 / GRID - 2 * INSET
        for f in new_faces:
            f.material_index = m
            f.smooth = smooth
            # planar projection on the face's dominant axis, normalised into the colour's cell
            n = f.normal
            ax = max(range(3), key=lambda i: abs(n[i]))
            a, b2 = [i for i in range(3) if i != ax]
            pts = [(lp.vert.co[a], lp.vert.co[b2]) for lp in f.loops]
            mnx, mny = min(p[0] for p in pts), min(p[1] for p in pts)
            ext = max(max(p[0] for p in pts) - mnx, max(p[1] for p in pts) - mny, 1e-6)
            for lp, p in zip(f.loops, pts):
                lp[self.uv].uv = (u0 + span * (p[0] - mnx) / ext, v0 + span * (p[1] - mny) / ext)
        return new_faces

    # --- primitives (rot in degrees, XYZ)
    def box(self, size, loc, m=0, col="#808080", bevel=0.01, rot=(0, 0, 0)):
        before = set(self.bm.faces)
        M = Matrix.Translation(loc) @ _rot(rot) @ Matrix.Diagonal((size[0], size[1], size[2], 1.0))
        bmesh.ops.create_cube(self.bm, size=1.0, matrix=M)
        return self._tag(before, m, col, False, min(bevel, min(size) * 0.45))

    def cyl(self, r, h, loc, m=0, col="#808080", r2=None, seg=12, rot=(0, 0, 0), bevel=0.0, smooth=True):
        """Cylinder / cone whose BOTTOM cap centre is at loc; axis = local +Z after rot."""
        before = set(self.bm.faces)
        M = Matrix.Translation(loc) @ _rot(rot) @ Matrix.Translation((0, 0, h / 2))
        bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg,
                              radius1=r, radius2=r if r2 is None else r2, depth=h, matrix=M)
        return self._tag(before, m, col, smooth, bevel, edges_only_sharp=True)

    def pipe(self, p0, p1, r, m=0, col="#808080", r2=None, seg=8, smooth=True):
        """Cylinder between two points (frames, arms, branches)."""
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        q = Vector((0, 0, 1)).rotation_difference(d.normalized())
        before = set(self.bm.faces)
        M = Matrix.Translation(p0) @ q.to_matrix().to_4x4() @ Matrix.Translation((0, 0, d.length / 2))
        bmesh.ops.create_cone(self.bm, cap_ends=True, cap_tris=False, segments=seg,
                              radius1=r, radius2=r if r2 is None else r2, depth=d.length, matrix=M)
        return self._tag(before, m, col, smooth, 0.0)

    def sphere(self, r, loc, m=0, col="#808080", seg=10, rings=6, scale=(1, 1, 1), smooth=True):
        before = set(self.bm.faces)
        M = Matrix.Translation(loc) @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))
        bmesh.ops.create_uvsphere(self.bm, u_segments=seg, v_segments=rings, radius=r, matrix=M)
        return self._tag(before, m, col, smooth, 0.0)

    def blob(self, r, loc, m=0, col="#808080", sub=1, scale=(1, 1, 1), rot=(0, 0, 0), smooth=True):
        """Icosphere lump (leaf masses, rocks, shrubs). sub=1 -> 80 tris."""
        before = set(self.bm.faces)
        M = Matrix.Translation(loc) @ _rot(rot) @ Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))
        bmesh.ops.create_icosphere(self.bm, subdivisions=sub, radius=r, matrix=M)
        return self._tag(before, m, col, smooth, 0.0)

    def quad(self, pts, m=0, col="#808080"):
        """Single double-sided-ready quad from 4 points (billboards, signs)."""
        before = set(self.bm.faces)
        vs = [self.bm.verts.new(p) for p in pts]
        self.bm.faces.new(vs)
        return self._tag(before, m, col, False, 0.0)

    def jitter(self, faces, amount, seed=1):
        """Deterministic vertex noise for organic parts (rocks, leaves)."""
        import random
        rnd = random.Random(seed)
        for v in {v for f in faces for v in f.verts}:
            v.co += Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-1, 1))) * amount

    # --- output
    def tris(self):
        return sum(len(f.verts) - 2 for f in self.bm.faces)

    def finish(self, x_offset=0.0):
        bmesh.ops.remove_doubles(self.bm, verts=self.bm.verts, dist=1e-5)
        me = bpy.data.meshes.new(self.name)
        self.bm.to_mesh(me)
        self.bm.free()
        for m in self.mats:
            me.materials.append(m)
        ob = bpy.data.objects.new(self.name, me)
        ob.location.x = x_offset
        (_KIT_COLL or bpy.context.scene.collection).objects.link(ob)
        return ob


def variants(name, mats, makers, spacing=3.0):
    """makers: list of callables f(builder). Returns [<name>_v1, <name>_v2, ...] objects."""
    out = []
    for i, fn in enumerate(makers):
        b = Builder("%s_v%d" % (name, i + 1), mats)
        fn(b)
        out.append(b.finish(i * spacing))
    return out


# ------------------------------------------------------------------ trees
def tree_mats():
    return [mat("Bark", rough=0.9), mat("Leaves", rough=0.7)]


def trunk(b, h, r, bark="#5A4636", seg=10, flare=1.7, lean=(0, 0)):
    """Tapered trunk with a root flare (4 roots) and slight lean. Returns the top point."""
    b.cyl(r * flare, 0.35, (0, 0, 0), m=0, col=bark, r2=r * 1.05, seg=seg)
    for i in range(4):
        a = math.radians(i * 90 + 25)
        b.pipe((math.cos(a) * r * 0.6, math.sin(a) * r * 0.6, 0.25),
               (math.cos(a) * r * 2.3, math.sin(a) * r * 2.3, -0.02), r * 0.32, m=0, col=bark, r2=r * 0.12, seg=5)
    top = (lean[0], lean[1], h)
    b.pipe((0, 0, 0.3), top, r, m=0, col=bark, r2=r * 0.55, seg=seg)
    return Vector(top)


def branches(b, base, n, length, r, rise, seed, bark="#5A4636", seg=6, start=0.55):
    """n branches around the trunk; returns their tip points (leaf mass anchors)."""
    import random
    rnd = random.Random(seed)
    tips = []
    for i in range(n):
        a = (i / n) * math.tau + rnd.uniform(-0.3, 0.3)
        z0 = base.z * (start + (1 - start) * i / max(1, n - 1)) * 0.92
        L = length * rnd.uniform(0.8, 1.15)
        p0 = Vector((base.x * z0 / base.z, base.y * z0 / base.z, z0))
        p1 = p0 + Vector((math.cos(a) * L, math.sin(a) * L, rise * rnd.uniform(0.7, 1.2)))
        b.pipe(p0, p1, r, m=0, col=bark, r2=r * 0.4, seg=seg)
        tips.append(p1)
    return tips


def leaf_masses(b, centers, r, leaf, seed, sub=1, squash=0.8):
    """Clustered icosphere leaf masses with per-cluster tint and noise."""
    import random
    rnd = random.Random(seed)
    for i, c in enumerate(centers):
        k = rnd.uniform(0.85, 1.15)
        tint = tuple(min(1.0, ch * rnd.uniform(0.85, 1.12)) for ch in rgb(leaf)[:3]) + (1.0,)
        f = b.blob(r * k, c, m=1, col=tint, sub=sub, scale=(1, 1, squash), rot=(0, 0, rnd.uniform(0, 90)))
        b.jitter(f, r * 0.12, seed + i)


def billboard(b, h, w, leaf, bark="#5A4636"):
    """Two crossed quads: lower third bark-tinted trunk strip is skipped, canopy-coloured cards."""
    for a in (0, 90):
        ca, sa = math.cos(math.radians(a)) * w / 2, math.sin(math.radians(a)) * w / 2
        b.quad([(-ca, -sa, 0), (ca, sa, 0), (ca, sa, h), (-ca, -sa, h)], m=1, col=leaf)
        b.quad([(-ca, -sa, h), (ca, sa, h), (ca, sa, 0), (-ca, -sa, 0)], m=1, col=leaf)


def tree_sets(name, specs, make_lod0, make_lod1, bb_size):
    """specs: list of dicts per variant (leaf colour etc). Builds LOD0, LOD1 and billboard sets."""
    mats = tree_mats()
    out = {"": [], "_lod1": [], "_bb": []}
    for i, s in enumerate(specs):
        for suffix, fn in (("", make_lod0), ("_lod1", make_lod1)):
            bl = Builder("%s%s_v%d" % (name, suffix, i + 1), mats)
            fn(bl, s)
            out[suffix].append(bl.finish(i * 8.0))
        bl = Builder("%s_bb_v%d" % (name, i + 1), mats)
        billboard(bl, bb_size[1], bb_size[0], s["leaf"])
        out["_bb"].append(bl.finish(i * 8.0))
    return out


# ------------------------------------------------------------------ export / run
def glb_abs(glb_path, suffix=""):
    rel = glb_path.replace("res://", "")
    if suffix:
        rel = rel[:-4] + suffix + ".glb"
    return os.path.join(ROOT, *rel.split("/"))


def _tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


def export(objs, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    kw = dict(filepath=path, export_format="GLB", use_selection=True, export_yup=True,
              export_apply=True, export_animations=False, export_materials="EXPORT")
    try:
        bpy.ops.export_scene.gltf(export_vertex_color="NONE", export_image_format="AUTO", **kw)  # 4.2+
    except TypeError:
        bpy.ops.export_scene.gltf(export_colors=False, **kw)
    print("[kit] exported", path)


def run(build, glb_path, limits=None):
    """Build, validate tris/material counts, export every LOD set. Returns the report rows."""
    reset(os.path.splitext(os.path.basename(glb_path))[0])
    _ATLAS.clear()
    res = build()
    sets = res if isinstance(res, dict) else {"": res}
    for mname in list(_ATLAS):   # all geometry is built -> every atlas colour is known
        bake(mname)
    rows = []
    for suffix, objs in sets.items():
        lo, hi = (limits or {}).get(suffix, PROP_TRIS)
        mats = {m.name for o in objs for m in o.data.materials}
        for o in objs:
            t = _tri_count(o)
            dims = tuple(round(d, 2) for d in o.dimensions)
            ok = lo <= t <= hi and len(mats) <= 2
            rows.append((o.name, t, dims, ok))
            print("[kit] %-28s tris=%5d size=%s %s" % (o.name, t, dims, "OK" if ok else "LIMIT!"))
        if len(mats) > 2:
            print("[kit] WARNING %s uses %d materials: %s" % (suffix or "lod0", len(mats), sorted(mats)))
        export(objs, glb_abs(glb_path, suffix))
    return rows
