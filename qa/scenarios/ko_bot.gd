extends "res://qa/scenarios/qa_scenario.gd"
## Issue C regression: defeated enemies fall and stay down.
## For each archetype, the 5 kill methods run in parallel (5 enemies 6 m apart on a line),
## then every body is sampled every 0.5 s for 90 s. Per case asserts:
##   - bone pose unchanged after landing (max bone drift < 0.03 m after the settle time)
##   - vertical extent of bone positions < 0.6 m (0.78 m for the brute)
##   - not in group 'enemy', in group 'enemy_body'
##   - visual.get_current_clip() never idle/run
##   - player not displaced (player stands next to the bodies, drift < 0.05 m)
##   - total 'enemy_body' count never above 16
## 3 screenshots per case (front, side, top) from a temporary Camera3D.
## Kills go through Enemy.take_hit(dmg, dir, kind) with kind = punch|launcher|finisher|gadget_explosion|fall.
## "roof fall": the enemy is spawned 12 m up and killed with kind 'fall' after it lands.

const ARCHETYPES: Array[StringName] = [&"thug", &"gunner", &"shield", &"brute", &"whip", &"sniper"]
const METHODS: Array[StringName] = [&"punches", &"launcher", &"finisher", &"gadget", &"roof_fall"]
const SAMPLE_S: float = 0.5
const HOLD_S: float = 90.0
const SETTLE_S: float = 2.5  # fall clip (<=48 frames @30 fps) + landing margin
const BODY_CAP: int = 16

var _max_bodies: int = 0


func run() -> void:
	var p: Node3D = await wait_player()
	if p == null:
		return
	var w: Node = get_world()
	if w == null or not w.has_method("spawn_enemies"):
		fail("World.spawn_enemies missing")
		return
	var origin: Vector3 = w.call("teleport_point", &"base") as Vector3 if w.has_method("teleport_point") else p.global_position
	# Use a flat street spot: drop to ground via ray.
	origin = _ground(origin + Vector3(30, 0, 0))
	var results: Dictionary = {}
	for arch: StringName in ARCHETYPES:
		results[String(arch)] = await _run_archetype(p, w, arch, origin)
	metrics["results"] = results
	metrics["max_body_count"] = _max_bodies
	if _max_bodies > BODY_CAP:
		fail("enemy_body count %d > %d" % [_max_bodies, BODY_CAP])
	var per_method: Dictionary = {}
	for m: StringName in METHODS:
		var ok: bool = true
		for a: String in results:
			ok = ok and bool((results[a] as Dictionary).get(String(m), {}).get("pass", false))
		per_method[String(m)] = ok
	metrics["per_method_pass"] = per_method


func _ground(at: Vector3) -> Vector3:
	var q := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 200.0, at + Vector3.DOWN * 50.0, 1)
	var hit: Dictionary = get_viewport().world_3d.direct_space_state.intersect_ray(q)
	return (hit["position"] as Vector3) if not hit.is_empty() else Vector3(at.x, 0.0, at.z)


func _run_archetype(p: Node3D, w: Node, arch: StringName, origin: Vector3) -> Dictionary:
	# Clear bodies from the previous archetype so screenshots show only this one.
	for b: Node in get_tree().get_nodes_in_group("enemy_body"):
		b.queue_free()
	await frames(3)
	var enemies: Array = []
	for i: int in METHODS.size():
		var at: Vector3 = origin + Vector3(i * 6.0, 0.0, 0.0)
		if METHODS[i] == &"roof_fall":
			at += Vector3.UP * 12.0
		# spawn_enemies offsets a single enemy by +3.5 m on X.
		var arr: Array = w.call("spawn_enemies", arch, 1, at - Vector3(3.5, 0, 0)) as Array
		enemies.append(arr[0] if not arr.is_empty() else null)
	# Player stands between case 1 and 2, close to the bodies.
	var stand: Vector3 = origin + Vector3(3.0, 0.2, 1.2)
	if p.has_method("teleport"):
		p.call("teleport", stand)
	await seconds(2.0)  # let roof enemy land
	for i: int in METHODS.size():
		var e: Node3D = enemies[i] as Node3D
		if is_instance_valid(e):
			_kill(e, p, METHODS[i])
	var res: Dictionary = {}
	var cases: Array[Dictionary] = []
	for i: int in METHODS.size():
		cases.append({"e": enemies[i], "spawned": is_instance_valid(enemies[i]), "ref": {}, "max_drift": 0.0, "max_extent": 0.0,
			"bad_clip": "", "group_ok": true, "alive_s": 0.0, "fails": [] as Array[String]})
	var p_ref: Vector3 = Vector3.INF
	var p_drift: float = 0.0
	var t: float = 0.0
	var limit: float = 0.78 if arch == &"brute" else 0.6
	while t < HOLD_S:
		await seconds(SAMPLE_S)
		t += SAMPLE_S
		bot(p, Vector2.ZERO, {})
		if is_instance_valid(p):
			if t >= SETTLE_S:
				if p_ref == Vector3.INF:
					p_ref = p.global_position
				p_drift = maxf(p_drift, p.global_position.distance_to(p_ref))
		_max_bodies = maxi(_max_bodies, get_tree().get_nodes_in_group("enemy_body").size())
		for c: Dictionary in cases:
			var raw: Variant = c["e"]
			if not is_instance_valid(raw):
				continue
			var e: Node3D = raw as Node3D
			c["alive_s"] = t
			if e.is_in_group("enemy") or not e.is_in_group("enemy_body"):
				c["group_ok"] = false
			var vis: Node = e.get("visual") as Node
			if vis != null and vis.has_method("get_current_clip"):
				var clip: StringName = vis.call("get_current_clip") as StringName
				if clip == &"idle" or clip == &"run":
					c["bad_clip"] = String(clip)
			if t < SETTLE_S:
				continue
			var bones: Dictionary = _bone_positions(e)
			if bones.is_empty():
				continue
			var lo: float = INF
			var hi: float = -INF
			for k: String in bones:
				var y: float = (bones[k] as Vector3).y
				lo = minf(lo, y)
				hi = maxf(hi, y)
			c["max_extent"] = maxf(float(c["max_extent"]), hi - lo)
			if (c["ref"] as Dictionary).is_empty():
				c["ref"] = bones
			else:
				var ref: Dictionary = c["ref"]
				for k: String in bones:
					if ref.has(k):
						c["max_drift"] = maxf(float(c["max_drift"]), (bones[k] as Vector3).distance_to(ref[k] as Vector3))
		if is_equal_approx(t, 5.0):
			for i: int in METHODS.size():
				var se: Variant = cases[i]["e"]
				if is_instance_valid(se):
					await _shots(se as Node3D, "%s_%s" % [arch, METHODS[i]])
	for i: int in METHODS.size():
		var c: Dictionary = cases[i]
		var f: Array[String] = []
		if not bool(c["spawned"]):
			f.append("not spawned")
		# 60 s lifetime counts from the KO in process time; sampling uses scenario timers, so allow 3 s slack.
		if float(c["alive_s"]) < 57.0:
			f.append("body gone after %.1f s (< 60)" % float(c["alive_s"]))
		if float(c["max_drift"]) > 0.03:
			f.append("bone drift %.3f m after landing" % float(c["max_drift"]))
		if float(c["max_extent"]) >= limit or float(c["max_extent"]) == 0.0:
			f.append("vertical extent %.2f m (limit %.2f)" % [float(c["max_extent"]), limit])
		if not bool(c["group_ok"]):
			f.append("group: still 'enemy' or not 'enemy_body'")
		if String(c["bad_clip"]) != "":
			f.append("clip returned to " + String(c["bad_clip"]))
		if p_drift > 0.05:
			f.append("player displaced %.3f m" % p_drift)
		for s: String in f:
			fail("%s/%s: %s" % [arch, METHODS[i], s])
		res[String(METHODS[i])] = {"pass": f.is_empty(), "failures": f,
			"max_bone_drift_m": snappedf(float(c["max_drift"]), 0.001),
			"max_extent_m": snappedf(float(c["max_extent"]), 0.001),
			"alive_s": float(c["alive_s"]), "player_drift_m": snappedf(p_drift, 0.001)}
	return res


func _kill(e: Node3D, p: Node3D, m: StringName) -> void:
	var dir: Vector3 = (e.global_position - p.global_position)
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	match m:
		&"punches":
			for i: int in 40:
				if bool(e.get("dead")):
					break
				e.call("take_hit", 10.0, dir, &"punch")
				e.set("_stun", 1.0)  # bypass shield block so the bot always lands hits
		&"launcher":
			e.call("take_hit", 9999.0, dir, &"launcher")
		&"finisher":
			e.call("take_hit", 9999.0, dir, &"finisher")
		&"gadget":
			e.call("take_hit", 9999.0, dir, &"gadget_explosion")
		&"roof_fall":
			e.call("take_hit", 9999.0, Vector3.ZERO, &"fall")


func _bone_positions(e: Node3D) -> Dictionary:
	var sk: Skeleton3D = _find_skeleton(e)
	var out: Dictionary = {}
	if sk == null:
		return out
	for i: int in sk.get_bone_count():
		out[sk.get_bone_name(i)] = sk.global_transform * sk.get_bone_global_pose(i).origin
	return out


func _find_skeleton(n: Node) -> Skeleton3D:
	for c: Node in n.get_children():
		if c is Skeleton3D:
			return c as Skeleton3D
		var r: Skeleton3D = _find_skeleton(c)
		if r != null:
			return r
	return null


func _shots(e: Node3D, label: String) -> void:
	if not is_instance_valid(e):
		return
	var prev: Camera3D = get_viewport().get_camera_3d()
	var cam := Camera3D.new()
	cam.fov = 50.0
	get_tree().current_scene.add_child(cam)
	var c: Vector3 = e.global_position + Vector3.UP * 0.3
	var views: Array = [["front", Vector3(0, 1.2, 3.5)], ["side", Vector3(3.5, 1.0, 0)], ["top", Vector3(0.5, 4.0, 0.5)]]
	for v: Array in views:
		cam.global_position = c + (v[1] as Vector3)
		cam.look_at(c, Vector3.UP)
		cam.make_current()
		await frames(2)
		await screenshot("%s_%s" % [label, String(v[0])])
	cam.queue_free()
	if prev != null:
		prev.make_current()
