extends "res://qa/scenarios/qa_scenario.gd"
## 10 fixed street spots (day 13:00 and night 23:00): distinct prop ids within 40 m
## (group 'prop', meta 'prop_id' or node name prefix), AABB overlap check between
## solid prop instances, and runs across curbs/crosswalks: the hero's horizontal
## speed must stay above 70% of the input run speed (else a snag event).

const RADIUS: float = 40.0
const MIN_TYPES: int = 8
const RUN_SPEED_KEY: StringName = &"run_speed"

var spots_out: Array = []
var snag_events: Array = []
var _box_names: Array[String] = []


func run() -> void:
	var p: Node3D = await wait_player()
	if p == null:
		return
	var w: Node = get_world()
	if w == null:
		fail("world missing")
		return
	var spots: Array[Vector3] = _pick_spots(w)
	metrics["spot_count"] = spots.size()
	if spots.size() < 10:
		fail("only %d spots (need 10)" % spots.size())
	for hour: float in [13.0, 23.0]:
		if w.has_method("set_time_of_day"):
			w.call("set_time_of_day", hour)
		for i: int in spots.size():
			var at: Vector3 = spots[i]
			p.call("teleport", at + Vector3.UP * 0.3)
			await seconds(1.0)
			var ids: Dictionary = _prop_ids_near(at)
			var r: Dictionary = {"spot": i, "hour": hour, "pos": [at.x, at.y, at.z],
				"prop_types": ids.size(), "ids": ids.keys()}
			spots_out.append(r)
			if ids.size() < MIN_TYPES:
				fail("spot %d hour %.0f: %d prop types < %d" % [i, hour, ids.size(), MIN_TYPES])
			await screenshot("spot%02d_%s" % [i, "day" if hour < 20.0 else "night"])
	metrics["spots"] = spots_out
	metrics["min_prop_types"] = _min_types()
	var ov: int = _overlap_check()
	metrics["overlaps"] = ov
	if ov > 0:
		fail("%d prop AABB overlaps" % ov)
	if w.has_method("set_time_of_day"):
		w.call("set_time_of_day", 13.0)
	await _runs(p, w)
	metrics["snag_events"] = snag_events
	metrics["snag_count"] = snag_events.size()
	if not snag_events.is_empty():
		fail("%d snag events" % snag_events.size())


## Sidewalk spots next to intersections (centre + 6 m diagonal onto the sidewalk).
func _pick_spots(w: Node) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if not w.has_method("get_intersections"):
		fail("World.get_intersections missing")
		return out
	var xs: PackedVector3Array = w.call("get_intersections") as PackedVector3Array
	var park: Rect2 = w.call("get_park_rect") as Rect2 if w.has_method("get_park_rect") else Rect2()
	var cands: Array[Vector3] = []
	for c: Vector3 in xs:
		if park.has_point(Vector2(c.x, c.z)) or park.grow(20.0).has_point(Vector2(c.x, c.z)):
			continue
		cands.append(c)
	cands.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.length() < b.length())
	var step: int = maxi(1, cands.size() / 10) if cands.size() > 40 else 1
	var i: int = 0
	while out.size() < 10 and i < cands.size():
		out.append(cands[i] + Vector3(7.0, 0.15, 7.0))
		i += step
	return out


func _prop_ids_near(at: Vector3) -> Dictionary:
	var ids: Dictionary = {}
	for n: Node in get_tree().get_nodes_in_group("prop"):
		if n is MultiMeshInstance3D:
			var mmi: MultiMeshInstance3D = n as MultiMeshInstance3D
			if mmi.multimesh == null or not mmi.is_visible_in_tree():
				continue
			for k: int in mmi.multimesh.instance_count:
				var pos: Vector3 = mmi.global_transform * mmi.multimesh.get_instance_transform(k).origin
				if pos.distance_to(at) <= RADIUS:
					ids[_prop_id(n)] = true
					break
		elif n is Node3D and (n as Node3D).global_position.distance_to(at) <= RADIUS:
			ids[_prop_id(n)] = true
	return ids


## Prop id from meta 'prop_id', else the node name up to "_v<N>" or "@".
func _prop_id(n: Node) -> String:
	if n.has_meta("prop_id"):
		return str(n.get_meta("prop_id"))
	var s: String = String(n.name).split("@")[0]
	var rx := RegEx.create_from_string("_v\\d+.*$")
	return rx.sub(s, "")


func _min_types() -> int:
	var m: int = 1 << 30
	for r: Dictionary in spots_out:
		m = mini(m, int(r["prop_types"]))
	return m if not spots_out.is_empty() else 0


## Counts pairs of solid prop colliders (StaticBody3D on layer 7) whose AABBs intersect.
func _overlap_check() -> int:
	var raw: Array[AABB] = []
	_box_names.clear()
	for n: Node in get_tree().get_nodes_in_group("prop"):
		_collect_boxes(n, raw)
	var order: Array = range(raw.size())
	order.sort_custom(func(a: int, b: int) -> bool: return raw[a].position.x < raw[b].position.x)
	var hits: int = 0
	var pairs: Array = []
	for ii: int in order.size():
		var i: int = order[ii]
		for jj: int in range(ii + 1, order.size()):
			var j: int = order[jj]
			if raw[j].position.x > raw[i].end.x:
				break
			if raw[i].grow(-0.02).intersects(raw[j].grow(-0.02)):
				hits += 1
				if pairs.size() < 30:
					var c: Vector3 = raw[i].get_center()
					pairs.append([_box_names[i], _box_names[j], snappedf(c.x, 0.1), snappedf(c.z, 0.1)])
	metrics["overlap_pairs"] = pairs
	return hits


func _collect_boxes(n: Node, out: Array[AABB]) -> void:
	for c: Node in n.get_children():
		if c is StaticBody3D and ((c as StaticBody3D).collision_layer & 64) != 0:
			for s: Node in c.get_children():
				var cs: CollisionShape3D = s as CollisionShape3D
				if cs == null or cs.shape == null or cs.disabled:
					continue
				var dbg: Mesh = cs.shape.get_debug_mesh()
				if dbg != null:
					out.append(cs.global_transform * dbg.get_aabb())
					_box_names.append(_prop_id(n))
		_collect_boxes(c, out)


## Runs along sidewalk graph edges, including crosswalk edges (curb up/down).
func _runs(p: Node3D, w: Node) -> void:
	if not w.has_method("get_sidewalk_graph"):
		fail("World.get_sidewalk_graph missing")
		return
	var g: Dictionary = w.call("get_sidewalk_graph") as Dictionary
	var nodes: PackedVector3Array = g.get("nodes", PackedVector3Array())
	var cw: PackedInt32Array = g.get("crosswalk_edges", PackedInt32Array())
	var ed: PackedInt32Array = g.get("edges", PackedInt32Array())
	var runs: Array = []
	var picks: Array[Vector2i] = []
	for k: int in range(0, mini(cw.size(), 12), 2):
		picks.append(Vector2i(cw[k], cw[k + 1]))
	for k: int in range(0, mini(ed.size(), 8), 2):
		picks.append(Vector2i(ed[k], ed[k + 1]))
	var tuning: Resource = p.get("tuning") as Resource
	var input_speed: float = float(tuning.get(RUN_SPEED_KEY)) if tuning != null and tuning.get(RUN_SPEED_KEY) != null else 0.0
	for e: Vector2i in picks:
		var a: Vector3 = nodes[e.x]
		var b: Vector3 = nodes[e.y]
		var dir: Vector3 = (b - a)
		dir.y = 0.0
		if dir.length() < 4.0:
			continue
		dir = dir.normalized()
		var start: Vector3 = a - dir * 6.0
		p.call("teleport", start + Vector3.UP * 0.3)
		await frames(3)
		p.look_at(p.global_position + dir, Vector3.UP)
		p.rotation.x = 0.0
		await seconds(0.3)
		var r: Dictionary = await _run_leg(p, start, b + dir * 4.0, dir, input_speed)
		runs.append(r)
	metrics["runs"] = runs
	metrics["input_speed"] = input_speed


func _run_leg(p: Node3D, start: Vector3, goal: Vector3, dir: Vector3, input_speed: float) -> Dictionary:
	var t: float = 0.0
	var peak: float = 0.0
	var min_after: float = INF
	var length: float = start.distance_to(goal)
	while t < length / 3.0 + 3.0:
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		# Steer toward goal in camera-independent fashion: player script maps move to camera,
		# so we keep forward input and rely on the initial facing.
		# Player input is camera-relative (wish = cam_basis * (x, 0, -y)), so map the leg direction
		# into camera space; the QA camera does not follow the hero's facing.
		var cb: Basis = p.call("cam_basis") as Basis if p.has_method("cam_basis") else Basis()
		var l: Vector3 = cb.inverse() * dir
		bot(p, Vector2(l.x, -l.z).normalized(), {})
		var v: Vector3 = player_velocity(p)
		var hv: float = Vector2(v.x, v.z).length()
		peak = maxf(peak, hv)
		var ref: float = input_speed if input_speed > 0.0 else peak
		if t > 1.0:
			min_after = minf(min_after, hv)
			if hv < 0.7 * ref:
				var near: Array = []
				var sq := PhysicsShapeQueryParameters3D.new()
				var sph := SphereShape3D.new()
				sph.radius = 1.2
				sq.shape = sph
				sq.transform = Transform3D(Basis(), p.global_position + Vector3.UP * 0.9)
				sq.collision_mask = 1 | 64
				for h: Dictionary in p.get_world_3d().direct_space_state.intersect_shape(sq, 8):
					var co: Object = h.get("collider")
					if co is Node and co != p:
						near.append(str((co as Node).get_path()))
				snag_events.append({"near": near, "t": snappedf(t, 0.01), "pos": [p.global_position.x, p.global_position.y, p.global_position.z], "speed": snappedf(hv, 0.01), "ref": snappedf(ref, 0.01)})
				await screenshot("snag%02d" % snag_events.size())
				break
		if (p.global_position - goal).dot(dir) > 0.0:
			break
	bot(p, Vector2.ZERO, {})
	return {"from": [start.x, start.z], "to": [goal.x, goal.z], "peak_speed": snappedf(peak, 0.01),
		"min_speed": snappedf(min_after, 0.01) if min_after != INF else 0.0}
