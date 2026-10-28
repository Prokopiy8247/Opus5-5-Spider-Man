extends "res://qa/scenarios/qa_scenario.gd"
## Lines up every model from data/props/manifest.json plus every park/*.glb (and road/*.glb)
## in rows of 5 at a far-away gallery spot and screenshots each row from 2 angles.
## Also counts variant meshes (<name>_v1, _v2 ...) and triangles per model.

const MANIFEST: String = "res://data/props/manifest.json"
const ORIGIN: Vector3 = Vector3(0, 400, 3000)
const PER_ROW: int = 5
const GAP: float = 7.0


func run() -> void:
	await wait_player()
	var paths: Array[String] = []
	var f: FileAccess = FileAccess.open(MANIFEST, FileAccess.READ)
	if f == null:
		fail("manifest missing: " + MANIFEST)
	else:
		var j: Variant = JSON.parse_string(f.get_as_text())
		if j is Dictionary and (j as Dictionary).get("props") is Array:
			for e: Variant in (j as Dictionary)["props"]:
				if e is Dictionary and (e as Dictionary).has("model"):
					paths.append(str((e as Dictionary)["model"]))
		else:
			fail("manifest has no 'props' array")
	for dir: String in ["res://assets/models/park/", "res://assets/models/road/"]:
		for fn: String in DirAccess.get_files_at(dir):
			if fn.ends_with(".glb") and not (dir + fn) in paths:
				paths.append(dir + fn)
	var root := Node3D.new()
	root.name = "PropGallery"
	get_tree().current_scene.add_child(root)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	root.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()  # backdrop floor for the screenshots only, not a prop
	pm.size = Vector2(80, 400)
	floor_mi.mesh = pm
	floor_mi.position = ORIGIN + Vector3(PER_ROW * GAP * 0.5, 0, 150)
	root.add_child(floor_mi)
	var models: Dictionary = {}
	var placed: Array[Node3D] = []
	for i: int in paths.size():
		var path: String = paths[i]
		var ps: PackedScene = load(path) as PackedScene if ResourceLoader.exists(path) else null
		if ps == null:
			fail("cannot load " + path)
			models[path.get_file().get_basename()] = {"loaded": false}
			continue
		var inst: Node3D = ps.instantiate() as Node3D
		inst.position = ORIGIN + Vector3((i % PER_ROW) * GAP, 0, (i / PER_ROW) * GAP)
		root.add_child(inst)
		placed.append(inst)
		var info: Dictionary = _inspect(inst)
		info["loaded"] = true
		models[path.get_file().get_basename()] = info
		var nm: String = path.get_file().get_basename()
		var is_lod: bool = nm.ends_with("_lod1") or nm.ends_with("_bb")
		if not is_lod and int(info["variants"]) < 2:
			fail("%s has %d variants (< 2)" % [nm, int(info["variants"])])
		if not is_lod and (int(info["tris"]) < 150 or int(info["tris"]) > 6000):
			fail("%s tris %d out of range" % [nm, int(info["tris"])])
	metrics["models"] = models
	metrics["model_count"] = models.size()
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	var rows: int = int(ceil(float(paths.size()) / PER_ROW))
	for row: int in rows:
		var centre: Vector3 = ORIGIN + Vector3((PER_ROW - 1) * GAP * 0.5, 1.2, row * GAP)
		cam.global_position = centre + Vector3(0, 3.5, -16)
		cam.look_at(centre, Vector3.UP)
		await frames(6)
		await screenshot("row%02d_front" % row)
		cam.global_position = centre + Vector3(14, 5, -10)
		cam.look_at(centre, Vector3.UP)
		await frames(6)
		await screenshot("row%02d_angle" % row)
	root.queue_free()
	var p: Node3D = get_player()
	var vp: Camera3D = null
	if p != null:
		for c: Node in p.find_children("*", "Camera3D", true, false):
			vp = c as Camera3D
	if vp != null:
		vp.current = true


## Variants = meshes named *_vN; tris summed over all MeshInstance3D (largest variant reported).
func _inspect(n: Node) -> Dictionary:
	var variants: int = 0
	var tris_max: int = 0
	var mats: int = 0
	for m: Node in n.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = m as MeshInstance3D
		if mi.mesh == null:
			continue
		var re := RegEx.create_from_string("_v\\d+$")
		if re.search(String(mi.name)) != null:
			variants += 1
		var t: int = 0
		for s: int in mi.mesh.get_surface_count():
			var arr: Array = mi.mesh.surface_get_arrays(s)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			t += (idx as PackedInt32Array).size() / 3 if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0 else (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		tris_max = maxi(tris_max, t)
		mats = maxi(mats, mi.mesh.get_surface_count())
	if mats > 2:
		fail("%s uses %d materials (> 2)" % [n.name, mats])
	return {"variants": maxi(variants, 1 if tris_max > 0 else 0), "tris": tris_max, "materials": mats}
