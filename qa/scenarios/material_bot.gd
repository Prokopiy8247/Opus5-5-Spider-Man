extends "res://qa/scenarios/qa_scenario.gd"
## Teleports to the main avenue (middle of get_avenue_lanes()[0], on the sidewalk),
## walks every MeshInstance3D / MultiMeshInstance3D within RADIUS and flags surfaces
## whose StandardMaterial3D has no albedo_texture and a near-white albedo_color
## (every sRGB channel > WHITE). Material/node names containing _paint/_glass/_emissive
## are exempt; ShaderMaterial surfaces (procedural concrete/tiles) are not flagged.
## Writes {pass, meshes_checked, white_surfaces: [{node_path, reason}]} + 00_street.png.

const RADIUS: float = 60.0
const WHITE: float = 0.85
const EXEMPT: Array[String] = ["_paint", "_glass", "_emissive"]

var white_surfaces: Array = []
var meshes_checked: int = 0


func run() -> void:
	var p: Node3D = await wait_player()
	if p == null:
		return
	var w: Node = get_world()
	if w == null:
		fail("world missing")
		return
	if w.has_method("set_time_of_day"):
		w.call("set_time_of_day", 13.0)
	var at: Vector3 = _avenue_spot(w)
	p.call("teleport", at + Vector3.UP * 0.3)
	await seconds(2.0)
	_scan(get_tree().root, at)
	metrics["spot"] = [at.x, at.y, at.z]
	metrics["meshes_checked"] = meshes_checked
	metrics["white_surfaces"] = white_surfaces
	if meshes_checked == 0:
		fail("no meshes within %.0f m" % RADIUS)
	if not white_surfaces.is_empty():
		fail("%d white untextured surfaces" % white_surfaces.size())
	await screenshot("street")


func _avenue_spot(w: Node) -> Vector3:
	if w.has_method("get_avenue_lanes"):
		var lanes: Array[PackedVector3Array] = w.call("get_avenue_lanes") as Array[PackedVector3Array]
		if not lanes.is_empty() and lanes[0].size() > 0:
			var lane: PackedVector3Array = lanes[0]
			return lane[lane.size() / 2] + Vector3(0.0, 0.15, 0.0)
	fail("World.get_avenue_lanes missing or empty")
	return Vector3.ZERO


func _scan(n: Node, at: Vector3) -> void:
	if n.is_in_group("player") or n.name == &"Player":
		return  # hero suit lenses/emblem are white by design; scope is street objects
	if n is GeometryInstance3D and (n as GeometryInstance3D).is_visible_in_tree():
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n as MeshInstance3D
			if mi.mesh != null and mi.global_position.distance_to(at) <= RADIUS:
				_check_mesh(mi, mi.mesh, mi)
		elif n is MultiMeshInstance3D:
			var mmi: MultiMeshInstance3D = n as MultiMeshInstance3D
			if mmi.multimesh != null and mmi.multimesh.mesh != null and _mmi_near(mmi, at):
				_check_mesh(mmi, mmi.multimesh.mesh, null)
	for c: Node in n.get_children():
		_scan(c, at)


func _mmi_near(mmi: MultiMeshInstance3D, at: Vector3) -> bool:
	for k: int in mmi.multimesh.instance_count:
		var pos: Vector3 = mmi.global_transform * mmi.multimesh.get_instance_transform(k).origin
		if pos.distance_to(at) <= RADIUS:
			return true
	return false


func _check_mesh(g: GeometryInstance3D, mesh: Mesh, mi: MeshInstance3D) -> void:
	meshes_checked += 1
	for s: int in mesh.get_surface_count():
		var mat: Material = g.material_override
		if mat == null and mi != null:
			mat = mi.get_active_material(s)
		if mat == null:
			mat = mesh.surface_get_material(s)
		var path: String = "%s:%d" % [str(g.get_path()), s]
		if _exempt(String(g.name)) or (mat != null and _exempt(mat.resource_name)):
			continue
		if mat == null:
			white_surfaces.append({"node_path": path, "reason": "no_material"})
			continue
		var sm: BaseMaterial3D = mat as BaseMaterial3D
		if sm == null:
			continue  # ShaderMaterial: procedural texture, not checked here
		if sm.albedo_texture != null:
			continue
		var c: Color = sm.albedo_color
		if c.r > WHITE and c.g > WHITE and c.b > WHITE:
			white_surfaces.append({"node_path": path, "reason": "near_white_no_texture",
				"material": mat.resource_name})


func _exempt(s: String) -> bool:
	for e: String in EXEMPT:
		if s.contains(e):
			return true
	return false
