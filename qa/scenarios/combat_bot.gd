extends "res://qa/scenarios/qa_scenario.gd"
## Teleports to a base, spawns thugs, mashes attack / dodges on spider-sense.
## Pass: at least 5 hits landed, combo >= 5 reached, player not KO'd below y -50.

var hits: int = 0
var max_combo: int = 0
var senses: int = 0
var damage_taken: float = 0.0


func run() -> void:
	var p: Node3D = await wait_player()
	if p == null:
		return
	var ev: Node = get_node_or_null("/root/Events")
	if ev != null:
		ev.connect("hit_landed", func(_t: Node3D, _d: float, c: int) -> void:
			hits += 1
			max_combo = maxi(max_combo, c))
		ev.connect("combo_changed", func(c: int) -> void: max_combo = maxi(max_combo, c))
		ev.connect("spider_sense", func(_a: Node3D, _w: bool) -> void: senses += 1)
		ev.connect("player_damaged", func(a: float, _d: Vector3) -> void: damage_taken += a)
	var w: Node = get_world()
	if w != null and w.has_method("teleport_point"):
		var pos: Vector3 = w.call("teleport_point", &"base") as Vector3
		if p.has_method("teleport"):
			p.call("teleport", pos)
	await seconds(1.0)
	if w != null and w.has_method("spawn_enemies"):
		w.call("spawn_enemies", &"thug", 3)
	await seconds(1.0)
	await _fight(p, 30.0)
	metrics["hits"] = hits
	metrics["max_combo"] = max_combo
	metrics["spider_senses"] = senses
	metrics["damage_taken"] = snappedf(damage_taken, 0.1)
	metrics["min_y"] = snappedf(p.global_position.y, 0.01) if is_instance_valid(p) else 0.0
	if hits < 5:
		fail("only %d hits landed" % hits)
	if max_combo < 5:
		fail("max combo %d < 5" % max_combo)


func _fight(p: Node3D, dur: float) -> void:
	var t: float = 0.0
	var dodge_cd: float = 0.0
	var sense_seen: int = 0
	var shot_t: float = 0.0
	while t < dur and is_instance_valid(p):
		await get_tree().physics_frame
		var dt: float = get_physics_process_delta_time()
		t += dt
		dodge_cd -= dt
		shot_t += dt
		var target: Node3D = _nearest_enemy(p)
		var move: Vector2 = Vector2.ZERO
		if target != null:
			var to: Vector3 = target.global_position - p.global_position
			if Vector2(to.x, to.z).length() > 2.5:
				move = Vector2(0, 1)
		var acts: Dictionary = {"attack": int(t * 10.0) % 2 == 0}
		if senses > sense_seen and dodge_cd <= 0.0:
			sense_seen = senses
			acts = {"dodge": true}
			dodge_cd = 0.5
		bot(p, move, acts)
		if shot_t > 5.0:
			shot_t = 0.0
			await screenshot("fight_t%02d" % int(t))
		if p.global_position.y < -50.0:
			bug("P0", "player below y=-50 in combat")
			break
	bot(p, Vector2.ZERO, {})


func _nearest_enemy(p: Node3D) -> Node3D:
	var best: Node3D = null
	var bd: float = INF
	for e: Node in get_tree().get_nodes_in_group("enemy"):
		var n3: Node3D = e as Node3D
		if n3 == null:
			continue
		var d: float = n3.global_position.distance_squared_to(p.global_position)
		if d < bd:
			bd = d
			best = n3
	return best
