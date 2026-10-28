extends "res://qa/scenarios/qa_scenario.gd"
## 10 fixed views captured before/after each milestone with a dedicated QA camera.
## Output: qa/evidence/before_set/<tag>/NN_<view>.png, tag from --tag=<b0|b1|b2|b3|b4> (default b0).

const TAGS: Array[String] = ["b0", "b1", "b2", "b3", "b4"]

var _cam: Camera3D


func run() -> void:
	var p: Node3D = await wait_player()
	var w: Node = get_world()
	if p == null or w == null:
		fail("player or world missing")
		return
	var tag: String = _tag()
	metrics["tag"] = tag
	shot_dir = ProjectSettings.globalize_path("res://qa/evidence/before_set/%s" % tag)
	DirAccess.make_dir_recursive_absolute(shot_dir)
	_cam = make_qa_camera(self)
	var views: Array = before_views(w)
	for v: Array in views:
		if v[3] >= 0.0 and w.has_method("set_time_of_day"):
			w.call("set_time_of_day", float(v[3]))
		await place_cam(_cam, p, v[1] as Vector3, v[2] as Vector3)
		await screenshot(String(v[0]))
	metrics["views"] = views.size()
	# metrics.json goes to qa/evidence/before_set/ (run_all checks it there); PNGs to the tag folder.
	if screenshots.size() != 10 and DisplayServer.get_name() != "headless":
		fail("%d of 10 views saved" % screenshots.size())
	metrics.merge(perf_snapshot(), false)


func _tag() -> String:
	for a: String in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if a.begins_with("--tag="):
			var t: String = a.substr(6).to_lower()
			if t in TAGS:
				return t
			fail("unknown tag '%s'" % t)
			return t if t.is_valid_identifier() else "b0"
	return "b0"


## [name, cam_pos, look_at, hour (<0 keeps current)] for the 10 contract views.
static func before_views(w: Node) -> Array:
	var xs: PackedVector3Array = w.call("get_intersections") as PackedVector3Array
	var c: Vector3 = Vector3.ZERO
	for x: Vector3 in xs:
		if c == Vector3.ZERO or x.length() < c.length():
			c = x
	var lm: Vector3 = w.call("teleport_point", &"landmark") as Vector3
	var br: Vector3 = w.call("teleport_point", &"bridge") as Vector3
	var bs: Vector3 = w.call("teleport_point", &"base") as Vector3
	var cz: float = float(w.get("CITY_Z")) if w.get("CITY_Z") != null else 750.0
	var wf: Vector3 = Vector3(c.x, 0.0, -cz + 20.0)
	return [
		["street_corner", c + Vector3(7, 1.7, 7), c + Vector3(-40, 8, -20), 13.0],
		["avenue", c + Vector3(0, 2.0, 8), c + Vector3(300, 20, 8), 13.0],
		["downtown_canyon", c + Vector3(4, 25, 4), c + Vector3(-200, 60, -200), 13.0],
		["aerial", c + Vector3(-150, 260, 150), c + Vector3(150, 0, -150), 13.0],
		["sunset", c + Vector3(-40, 90, 40), c + Vector3(200, 60, -100), 18.8],
		["night", c + Vector3(-40, 90, 40), c + Vector3(200, 60, -100), 23.0],
		["landmark", lm + Vector3(120, 30, 120), lm + Vector3(0, 120, 0), 13.0],
		["bridge", br + Vector3(80, 20, 80), br + Vector3(0, 30, 0), 13.0],
		["base", bs + Vector3(30, 15, 30), bs, 13.0],
		["waterfront", wf + Vector3(0, 12, -60), wf + Vector3(0, 10, 60), 13.0],
	]
