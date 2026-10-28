class_name InstanceBatcher
extends RefCounted
## Collects world transforms per (model path, variant, 128 m chunk) and flushes them into one
## MultiMeshInstance3D each, registered with ChunkStreamer. Optional colliders go into one
## StaticBody3D (layer 7, value 64) per MMI as its child, so QA can find them under group 'prop'.
## Variant meshes come from MeshKit; the per-variant x offset Blender uses to lay variants out
## side by side is dropped (only the import basis is kept), so every pivot is the ground centre.

const PROP_LAYER: int = 64

var group: StringName = &"prop"
var _bins: Dictionary = {}       # "path|variant|kx|ky" -> {"path","v","k","xfs":Array[Transform3D],"col":Array}
var _shapes: Dictionary = {}     # id -> Shape3D
var vis_end: float = 0.0
var cast_shadows: bool = true


## Number of variants available for a model (0 when the glb is missing).
static func variant_count(path: String) -> int:
	return MeshKit.variants(path).size()


## Adds one instance. variant < 0 picks by hash of the position. Returns false if the model is missing.
func add(id: String, path: String, xf: Transform3D, variant: int = -1, collider: Dictionary = {}) -> bool:
	var vs: Array = MeshKit.variants(path)
	if vs.is_empty():
		return false
	var v: int = variant
	if v < 0:
		v = posmod(int(xf.origin.x * 7.31) * 31 + int(xf.origin.z * 3.17), vs.size())
	v = posmod(v, vs.size())
	var k: Vector2i = MeshKit.chunk_key(xf.origin)
	var key: String = "%s|%d|%d|%d" % [path, v, k.x, k.y]
	if not _bins.has(key):
		_bins[key] = {"id": id, "path": path, "v": v, "k": k, "xfs": [] as Array[Transform3D], "col": []}
	var b: Dictionary = _bins[key]
	(b["xfs"] as Array[Transform3D]).append(xf)
	if not collider.is_empty():
		(b["col"] as Array).append([xf, collider])
	return true


## Builds every MMI under parent and registers them with streamer (may be null).
func flush(parent: Node3D, streamer: ChunkStreamer) -> int:
	var made: int = 0
	for key: String in _bins:
		var b: Dictionary = _bins[key]
		var ent: Dictionary = (MeshKit.variants(b["path"]) as Array)[int(b["v"])]
		var local: Transform3D = Transform3D((ent["xf"] as Transform3D).basis, Vector3.ZERO)
		var src: Array[Transform3D] = b["xfs"]
		var xfs: Array[Transform3D] = []
		for x: Transform3D in src:
			xfs.append(x * local)
		var mmi: MultiMeshInstance3D = MeshKit.make_mmi(ent["mesh"] as Mesh, xfs, MeshKit.chunk_center(b["k"] as Vector2i), vis_end)
		mmi.name = "%s_v%d_%d_%d" % [b["id"], int(b["v"]) + 1, (b["k"] as Vector2i).x, (b["k"] as Vector2i).y]
		mmi.set_meta(&"prop_id", b["id"])
		mmi.add_to_group(group)
		if not cast_shadows:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mmi)
		var cols: Array = b["col"]
		if not cols.is_empty():
			var body: StaticBody3D = StaticBody3D.new()
			body.name = "Colliders"
			body.collision_layer = PROP_LAYER
			body.collision_mask = 0
			mmi.add_child(body)
			for c: Array in cols:
				_add_shape(body, b["id"], c[0] as Transform3D, c[1] as Dictionary)
		if streamer != null:
			streamer.register_node(mmi)
		made += 1
	_bins.clear()
	return made


## collider = {"type": "box|cylinder|capsule", "size": Vector3}; shapes sit on the pivot (ground).
func _add_shape(body: StaticBody3D, id: String, xf: Transform3D, c: Dictionary) -> void:
	var t: String = str(c.get("type", "none"))
	var s: Vector3 = c.get("size", Vector3.ONE)
	if t == "none" or s.y <= 0.0:
		return
	var sk: String = "%s|%s|%s" % [id, t, str(s)]
	if not _shapes.has(sk):
		var sh: Shape3D
		match t:
			"box":
				var bs: BoxShape3D = BoxShape3D.new()
				bs.size = s
				sh = bs
			"capsule":
				var cp: CapsuleShape3D = CapsuleShape3D.new()
				cp.radius = maxf(s.x, 0.05)
				cp.height = maxf(s.y, cp.radius * 2.0 + 0.01)
				sh = cp
			_:
				var cy: CylinderShape3D = CylinderShape3D.new()
				cy.radius = maxf(s.x, 0.05)
				cy.height = s.y
				sh = cy
		_shapes[sk] = sh
	var cs: CollisionShape3D = CollisionShape3D.new()
	cs.shape = _shapes[sk]
	# Keep only yaw: shapes stay upright even if the instance is scaled.
	var yaw: Basis = Basis(Vector3.UP, atan2(-xf.basis.z.x, -xf.basis.z.z) + PI)
	cs.transform = Transform3D(yaw, xf.origin + Vector3.UP * s.y * 0.5)
	body.add_child(cs)
