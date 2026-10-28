extends "res://qa/scenarios/qa_scenario.gd"
## Checks the detailed traffic car model res://assets/models/car.glb and that traffic uses it.
## metrics.json contains exactly: pass, car_model_from_glb, cars, tris, objects_found,
## materials_found, missing, aabb_size.

const CAR_PATH: String = "res://assets/models/car.glb"
const OBJECTS: Array[String] = ["Body", "Cabin", "Windows", "Bumpers", "Grille", "Mirrors",
		"Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR", "Headlights", "Brakelights"]
const MATERIALS: Array[String] = ["Car_Paint", "Car_Glass", "Car_Tire", "Car_Rim", "Car_Trim",
		"Car_Headlight", "Car_Brakelight"]
const TRIS_MIN: int = 1500
const TRIS_MAX: int = 4000
const AABB_TARGET: Vector3 = Vector3(1.9, 1.5, 4.4)
const AABB_TOL: float = 0.1
const SHOT_DIST: float = 6.0

var _tris: int = 0
var _objects: Array[String] = []
var _materials: Array[String] = []
var _aabb: AABB = AABB()
var _aabb_set: bool = false


func run() -> void:
	var missing: Array[String] = []
	var ok: bool = true
	_inspect_model()
	for o: String in OBJECTS:
		if not _objects.has(o):
			missing.append(o)
	for m: String in MATERIALS:
		if not _materials.has(m):
			missing.append(m)
	if not missing.is_empty():
		fail("missing in car.glb: %s" % ", ".join(missing))
	if _tris < TRIS_MIN or _tris > TRIS_MAX:
		fail("tris %d outside %d..%d" % [_tris, TRIS_MIN, TRIS_MAX])
	var size: Vector3 = _aabb.size if _aabb_set else Vector3.ZERO
	if absf(size.x - AABB_TARGET.x) > AABB_TOL or absf(size.y - AABB_TARGET.y) > AABB_TOL \
			or absf(size.z - AABB_TARGET.z) > AABB_TOL:
		fail("aabb_size %s not within %.2f of %s" % [size, AABB_TOL, AABB_TARGET])

	# --- traffic
	var p: Node3D = await wait_player()
	var cars: Array[Node] = []
	await wait_until(func() -> bool:
		return not get_tree().get_nodes_in_group(&"traffic_car").is_empty(), 10.0)
	await seconds(1.0)
	cars = get_tree().get_nodes_in_group(&"traffic_car")
	var all_glb: bool = not cars.is_empty()
	for c: Node in cars:
		if not (c.has_method("uses_glb_model") and bool(c.call("uses_glb_model"))):
			all_glb = false
	if cars.is_empty():
		fail("no TrafficCar in group 'traffic_car'")
	elif not all_glb:
		fail("not all cars use car.glb")

	await _shoot_car(cars, p)
	ok = failures.is_empty()
	metrics = {
		"pass": ok,
		"car_model_from_glb": all_glb,
		"cars": cars.size(),
		"tris": _tris,
		"objects_found": _objects,
		"materials_found": _materials,
		"missing": missing,
		"aabb_size": [snappedf(size.x, 0.001), snappedf(size.y, 0.001), snappedf(size.z, 0.001)],
	}


## Instantiates car.glb off-tree and collects tris, names, materials and the merged AABB.
func _inspect_model() -> void:
	if not ResourceLoader.exists(CAR_PATH):
		fail("%s not found" % CAR_PATH)
		return
	var ps: PackedScene = load(CAR_PATH) as PackedScene
	if ps == null:
		fail("%s is not a PackedScene" % CAR_PATH)
		return
	var root: Node = ps.instantiate()
	_walk(root, Transform3D.IDENTITY, true)
	root.free()


func _walk(n: Node, parent_xf: Transform3D, is_root: bool) -> void:
	var xf: Transform3D = parent_xf
	var n3: Node3D = n as Node3D
	if n3 != null and not is_root:
		xf = parent_xf * n3.transform
	if not is_root:
		var nm: String = String(n.name)
		if not _objects.has(nm):
			_objects.append(nm)
	var mi: MeshInstance3D = n as MeshInstance3D
	if mi != null and mi.mesh != null:
		var mesh: Mesh = mi.mesh
		for s: int in mesh.get_surface_count():
			_tris += _surface_tris(mesh, s)
			var mat: Material = mi.get_surface_override_material(s)
			if mat == null:
				mat = mesh.surface_get_material(s)
			if mat != null:
				var mn: String = mat.resource_name
				if mn != "" and not _materials.has(mn):
					_materials.append(mn)
		var box: AABB = xf * mesh.get_aabb()
		_aabb = box if not _aabb_set else _aabb.merge(box)
		_aabb_set = true
	for c: Node in n.get_children():
		_walk(c, xf, false)


func _surface_tris(mesh: Mesh, s: int) -> int:
	var arr: Array = mesh.surface_get_arrays(s)
	if arr.is_empty():
		return 0
	var idx: Variant = arr[Mesh.ARRAY_INDEX]
	if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0:
		return (idx as PackedInt32Array).size() / 3
	var v: Variant = arr[Mesh.ARRAY_VERTEX]
	if v is PackedVector3Array:
		return (v as PackedVector3Array).size() / 3
	return 0


## Screenshot from about 6 m at the slowest car (prefers one near the player).
func _shoot_car(cars: Array[Node], p: Node3D) -> void:
	var best: Node3D = null
	var best_score: float = INF
	for c: Node in cars:
		var c3: Node3D = c as Node3D
		if c3 == null or not c3.is_inside_tree():
			continue
		var spd: float = 0.0
		var sv: Variant = c3.get(&"speed")
		if sv is float:
			spd = absf(float(sv))
		var dist: float = c3.global_position.distance_to(p.global_position) if p != null else 0.0
		var score: float = spd * 100.0 + dist
		if score < best_score:
			best_score = score
			best = c3
	if best == null:
		await screenshot("cars")
		return
	var cam := Camera3D.new()
	cam.name = "CarModelBotCam"
	get_tree().current_scene.add_child(cam)
	var prev: Camera3D = get_viewport().get_camera_3d()
	for i: int in 3:
		if not is_instance_valid(best):
			break
		# Front three-quarter view: car front is -Z in its local space.
		var dir: Vector3 = (-best.global_basis.z + best.global_basis.x * 0.8).normalized()
		var target: Vector3 = best.global_position + Vector3(0, 0.7, 0)
		cam.global_position = target + dir * SHOT_DIST + Vector3(0, 1.5, 0)
		cam.look_at(target, Vector3.UP)
		cam.make_current()
		await frames(1)
	await screenshot("cars")
	if prev != null and is_instance_valid(prev):
		prev.make_current()
	cam.queue_free()


## Writes only the contract fields (overrides the common schema of the base class).
func finish() -> void:
	if _finished:
		return
	_finished = true
	var ok: bool = failures.is_empty() and bool(metrics.get("pass", false))
	var out: Dictionary = metrics.duplicate()
	out["pass"] = ok
	for k: String in ["car_model_from_glb", "cars", "tris", "objects_found", "materials_found",
			"missing", "aabb_size"]:
		if not out.has(k):
			out[k] = false if k == "car_model_from_glb" else 0
	var f: FileAccess = FileAccess.open(evidence_dir + "/metrics.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "  "))
		f.close()
	result_pass = ok
	print("[QA] scenario %s %s" % [scenario_name, "PASS" if ok else "FAIL"])
	if standalone:
		get_tree().quit.call_deferred(0 if ok else 1)
