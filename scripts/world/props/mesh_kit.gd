class_name MeshKit
extends RefCounted
## Shared loader for Blender-exported prop/road/park glb files.
## variants(path) returns one entry per variant mesh (<name>_v1, <name>_v2 ...) with its
## local transform inside the glb, so MultiMeshes can reuse the meshes directly.
## Missing files are skipped with a single print (never push_warning: logs must stay clean).
## Materials named Emit_* are registered once and driven by set_night_factor().

static var _cache: Dictionary = {}     # path -> Array[Dictionary]
static var _reported: Dictionary = {}  # path -> true
static var emit_mats: Array[Material] = []
static var _emit_seen: Dictionary = {}  # material instance id -> true
static var night_factor: float = 0.0


## Returns Array of {"mesh": Mesh, "xf": Transform3D, "name": String}, sorted by name.
## quiet = true for optional files (lod1, billboards): no print when absent.
static func variants(path: String, quiet: bool = false) -> Array:
	if _cache.has(path):
		return _cache[path]
	var out: Array = []
	_cache[path] = out
	if not ResourceLoader.exists(path):
		if not quiet and not _reported.has(path):
			_reported[path] = true
			print("[MeshKit] model missing, prop skipped: ", path)
		return out
	var ps: PackedScene = load(path) as PackedScene
	if ps == null:
		if not quiet:
			print("[MeshKit] not a scene, prop skipped: ", path)
		return out
	var root: Node = ps.instantiate()
	var stack: Array = [[root, Transform3D.IDENTITY]]
	while not stack.is_empty():
		var pair: Array = stack.pop_back()
		var n: Node = pair[0]
		var xf: Transform3D = pair[1]
		if n != root and n is Node3D:
			xf = xf * (n as Node3D).transform
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi != null and mi.mesh != null:
			var mesh: Mesh = _bake(mi)
			_register_emissive(mesh)
			out.append({"mesh": mesh, "xf": xf, "name": String(mi.name)})
		for c: Node in n.get_children():
			stack.append([c, xf])
	root.free()
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["name"]) < String(b["name"]))
	return out


static func has_model(path: String) -> bool:
	return not variants(path).is_empty()


## Copies surface-override materials into a mesh copy so MultiMesh renders them.
static func _bake(mi: MeshInstance3D) -> Mesh:
	var needs: bool = mi.material_override != null
	for s: int in mi.mesh.get_surface_count():
		if mi.get_surface_override_material(s) != null:
			needs = true
	if not needs:
		return mi.mesh
	var m: Mesh = mi.mesh.duplicate() as Mesh
	for s: int in m.get_surface_count():
		var mat: Material = mi.get_active_material(s)
		if mat != null:
			m.surface_set_material(s, mat)
	return m


static func _register_emissive(mesh: Mesh) -> void:
	for s: int in mesh.get_surface_count():
		var mat: Material = mesh.surface_get_material(s)
		if mat == null or not (mat.resource_name.ends_with("_emissive") or mat.resource_name.begins_with("Emit_")):
			continue
		var id: int = mat.get_instance_id()
		if _emit_seen.has(id):
			continue
		_emit_seen[id] = true
		if mat is BaseMaterial3D:
			var bm: BaseMaterial3D = mat as BaseMaterial3D
			bm.emission_enabled = true
			if not bm.has_meta(&"emit_base"):
				bm.set_meta(&"emit_base", maxf(bm.emission_energy_multiplier, 1.0))
		emit_mats.append(mat)
		_apply_night(mat)


## Duplicates a mesh with its own copies of the materials whose names start with prefix.
## Returns {"mesh": Mesh, "mats": {material_name: Material}} (used for per-group signal lamps).
static func clone_with_own_materials(mesh: Mesh, prefix: String) -> Dictionary:
	var m: Mesh = mesh.duplicate() as Mesh
	var mats: Dictionary = {}
	for s: int in m.get_surface_count():
		var mat: Material = m.surface_get_material(s)
		if mat != null and mat.resource_name.begins_with(prefix):
			var d: Material = mat.duplicate() as Material
			d.resource_name = mat.resource_name
			m.surface_set_material(s, d)
			mats[mat.resource_name] = d
	return {"mesh": m, "mats": mats}


static func set_night_factor(f: float) -> void:
	night_factor = clampf(f, 0.0, 1.0)
	for m: Material in emit_mats:
		_apply_night(m)


static func _apply_night(m: Material) -> void:
	if m is ShaderMaterial:
		(m as ShaderMaterial).set_shader_parameter(&"night_factor", night_factor)
	elif m is BaseMaterial3D:
		var bm: BaseMaterial3D = m as BaseMaterial3D
		var base: float = float(bm.get_meta(&"emit_base", 1.0))
		bm.emission_energy_multiplier = base * lerpf(0.15, 3.0, night_factor)


## One MultiMeshInstance3D for a mesh variant; xfs are world transforms (already multiplied
## by the variant's local transform). Registered by the caller with ChunkStreamer.
static func make_mmi(mesh: Mesh, xfs: Array[Transform3D], center: Vector3, vis_end: float = 0.0, vis_begin: float = 0.0) -> MultiMeshInstance3D:
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i: int in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.set_meta(&"stream_center", center)
	if vis_end > 0.0:
		mmi.visibility_range_end = vis_end
		mmi.visibility_range_begin = vis_begin
	return mmi


static func chunk_key(p: Vector3) -> Vector2i:
	return Vector2i(floori(p.x / 128.0), floori(p.z / 128.0))


static func chunk_center(k: Vector2i) -> Vector3:
	return Vector3((float(k.x) + 0.5) * 128.0, 0.0, (float(k.y) + 0.5) * 128.0)


## Small deterministic hash -> seed (city seed + integer keys).
static func seed_of(a: int, b: int, c: int = 0, d: int = 0) -> int:
	var h: int = 2166136261
	for v: int in [a, b, c, d]:
		h = (h ^ (v & 0xffffffff)) * 16777619
		h = h & 0x7fffffff
	return h
