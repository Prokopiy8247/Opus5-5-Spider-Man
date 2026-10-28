extends "res://qa/scenarios/qa_scenario.gd"
## Samples frame times at spawn, while swinging, and at each teleport point.
## Iteration 2 adds dense_downtown, park_ground and avenue_parked at street level.
## Pass: avg_fps >= 120 and 1% low >= 60 overall and in every dense section.

var _frame_ms: Array[float] = []
var _sampling: bool = false


func _process(delta: float) -> void:
	super(delta)
	if _sampling:
		_frame_ms.append(delta * 1000.0)


func run() -> void:
	var p: Node3D = await wait_player()
	if p == null:
		return
	await seconds(2.0)  # warm-up
	var sections: Dictionary = {}
	sections["spawn"] = await _sample(5.0)
	_sampling = true
	var st: Dictionary = await drive_swing(p, 20.0, 0.0, 3.0, 0.0)
	_sampling = false
	sections["swinging"] = _stats()
	sections["swinging"]["distance_m"] = st["distance_m"]
	var w: Node = get_world()
	if w != null and w.has_method("teleport_point"):
		for id: StringName in [&"downtown", &"park", &"bridge", &"landmark", &"base"]:
			var pos: Vector3 = w.call("teleport_point", id) as Vector3
			if p.has_method("teleport"):
				p.call("teleport", pos)
			await seconds(1.0)
			sections[String(id)] = await _sample(4.0)
			await screenshot(String(id))
	# Iteration 2: street-level dense scenes. Each must hold avg >= 120 and 1% low >= 60.
	var dense: Array[String] = []
	if w != null and p.has_method("teleport"):
		var spots: Dictionary = _dense_spots(w)
		for k: String in spots:
			var sp: Array = spots[k] as Array
			p.call("teleport", sp[0] as Vector3)
			p.look_at(sp[1] as Vector3, Vector3.UP)
			await seconds(1.5)
			sections[k] = await _sample(5.0)
			dense.append(k)
			await screenshot(k)
	else:
		fail("world/teleport missing: dense sections not measured")
	var all: Array[float] = []
	for k: String in sections:
		all.append_array(sections[k]["_raw"] as Array[float])
		sections[k].erase("_raw")
	_frame_ms = all
	var tot: Dictionary = _stats()
	tot.erase("_raw")
	metrics["sections"] = sections
	metrics["dense_sections"] = dense
	metrics.merge(tot, true)
	metrics.merge(perf_snapshot(), false)
	metrics["peak_static_mem_mb"] = Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / 1048576.0
	if float(tot["avg_fps"]) < 120.0:
		fail("avg_fps %.1f < 120" % float(tot["avg_fps"]))
	if float(tot["low1_fps"]) < 60.0:
		fail("1%% low %.1f < 60" % float(tot["low1_fps"]))
	for k: String in dense:
		if float(sections[k]["avg_fps"]) < 120.0:
			fail("%s avg_fps %.1f < 120" % [k, float(sections[k]["avg_fps"])])
		if float(sections[k]["low1_fps"]) < 60.0:
			fail("%s 1%% low %.1f < 60" % [k, float(sections[k]["low1_fps"])])


## {name: [position, look_at]} for dense downtown (intersection nearest the origin),
## park ground (park teleport, which sits on a path) and an avenue with parked cars
## (sidewalk next to the middle of the first avenue lane).
func _dense_spots(w: Node) -> Dictionary:
	var out: Dictionary = {}
	if w.has_method("get_intersections"):
		var xs: PackedVector3Array = w.call("get_intersections") as PackedVector3Array
		var best: Vector3 = Vector3.INF
		for x: Vector3 in xs:
			if best == Vector3.INF or x.length() < best.length():
				best = x
		if best != Vector3.INF:
			out["dense_downtown"] = [best + Vector3(6.0, 1.2, 6.0), best + Vector3(-30.0, 2.0, -30.0)]
	if w.has_method("get_park_rect"):
		var r: Rect2 = w.call("get_park_rect") as Rect2
		var tp: Vector3 = w.call("teleport_point", &"park") as Vector3
		out["park_ground"] = [tp, Vector3(r.get_center().x, 2.0, r.get_center().y) + Vector3(1, 0, 1)]
	if w.has_method("get_avenue_lanes"):
		var lanes: Array = w.call("get_avenue_lanes") as Array
		if not lanes.is_empty() and (lanes[0] as PackedVector3Array).size() >= 2:
			var l: PackedVector3Array = lanes[0] as PackedVector3Array
			var m: Vector3 = l[l.size() / 2]
			var dir: Vector3 = (l[l.size() - 1] - l[0]).normalized()
			var side: Vector3 = dir.cross(Vector3.UP)
			out["avenue_parked"] = [m + side * 9.0 + Vector3.UP * 1.3, m + dir * 60.0 + Vector3.UP * 2.0]
	for k: String in ["dense_downtown", "park_ground", "avenue_parked"]:
		if not out.has(k):
			fail("cannot locate perf spot " + k)
	return out


func _sample(s: float) -> Dictionary:
	_frame_ms = []
	_sampling = true
	var dc_max: float = 0.0
	var t: float = 0.0
	while t < s:
		await get_tree().process_frame
		t += get_process_delta_time()
		dc_max = maxf(dc_max, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	_sampling = false
	var r: Dictionary = _stats()
	r["draw_calls_max"] = dc_max
	return r


func _stats() -> Dictionary:
	var a: Array[float] = _frame_ms.duplicate()
	var r: Dictionary = {"_raw": a.duplicate()}
	if a.is_empty():
		r["avg_fps"] = 0.0
		r["low1_fps"] = 0.0
		return r
	var sum: float = 0.0
	for x: float in a:
		sum += x
	a.sort()
	var worst_n: int = maxi(1, a.size() / 100)
	var worst_sum: float = 0.0
	for i: int in worst_n:
		worst_sum += a[a.size() - 1 - i]
	r["avg_fps"] = snappedf(1000.0 / (sum / a.size()), 0.1)
	r["low1_fps"] = snappedf(1000.0 / (worst_sum / worst_n), 0.1)
	r["max_frame_ms"] = snappedf(a[a.size() - 1], 0.01)
	r["frames"] = a.size()
	return r
