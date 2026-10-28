extends "res://qa/scenarios/qa_scenario.gd"
## Checks that hero / enemy models face their movement direction and that traffic
## cars use the Blender car.glb model.
## Pass: hero_facing_dot >= 0.9, enemy_facing_dot >= 0.9, cars > 0, car_model_from_glb.

const DOT_MIN: float = 0.9
const RUN_S: float = 3.0
const MIN_SPEED: float = 1.0


func run() -> void:
	var p: Node3D = await wait_player()
	if p == null:
		metrics["pass"] = false
		return
	var w: Node = get_world()
	# Ground run: park is at street level (spawn is on a rooftop).
	if w != null and w.has_method("teleport_point") and p.has_method("teleport"):
		p.call("teleport", w.call("teleport_point", &"park") as Vector3)
	await seconds(1.0)

	# --- hero: 3 s forward run, timed by physics delta (not frame count)
	var t: float = 0.0
	var hero_dot: float = -2.0
	var shot_done: bool = false
	while t < RUN_S and is_instance_valid(p):
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		bot(p, Vector2(0, 1), {})
		if not shot_done and t > RUN_S * 0.7:
			shot_done = true
			await screenshot("run")
	if is_instance_valid(p):
		hero_dot = _facing_dot(p, player_velocity(p))
	bot(p, Vector2.ZERO, {})
	metrics["hero_facing_dot"] = snappedf(hero_dot, 0.001)
	if hero_dot < DOT_MIN:
		fail("hero_facing_dot %.3f < %.2f" % [hero_dot, DOT_MIN])

	# --- enemy: spawn a thug and wait until it walks toward the player
	var enemy_dot: float = -2.0
	if w != null and w.has_method("spawn_enemies") and is_instance_valid(p):
		var spawned: Array = w.call("spawn_enemies", &"thug", 1,
				p.global_position + (-p.global_basis.z) * 12.0) as Array
		var e: CharacterBody3D = (spawned[0] as CharacterBody3D) if not spawned.is_empty() else null
		if e != null:
			await seconds(0.2)
			# Force combat so the thug chases the player regardless of perception.
			if is_instance_valid(e):
				e.set(&"awareness", 1.0)
				e.call(&"_set_state", &"alert")
			var moving: bool = await wait_until(func() -> bool:
				return is_instance_valid(e) and Vector2(e.velocity.x, e.velocity.z).length() > MIN_SPEED, 8.0)
			# a few frames so the visual can turn toward the velocity
			await seconds(0.4)
			if moving and is_instance_valid(e):
				enemy_dot = _facing_dot(e, e.velocity)
			else:
				fail("thug never moved (horizontal speed <= %.1f)" % MIN_SPEED)
				if is_instance_valid(e):
					print("[QA] thug state=%s pos=%s player=%s" % [e.get(&"state"), e.global_position, p.global_position])
		else:
			fail("spawn_enemies returned no thug")
	else:
		fail("world.spawn_enemies unavailable")
	metrics["enemy_facing_dot"] = snappedf(enemy_dot, 0.001)
	if enemy_dot < DOT_MIN:
		fail("enemy_facing_dot %.3f < %.2f" % [enemy_dot, DOT_MIN])

	# --- traffic cars
	var cars: Array[Node] = get_tree().get_nodes_in_group(&"traffic_car")
	var all_glb: bool = not cars.is_empty()
	for c: Node in cars:
		if not (c.has_method("uses_glb_model") and bool(c.call("uses_glb_model"))):
			all_glb = false
	metrics["cars"] = cars.size()
	metrics["car_model_from_glb"] = all_glb
	if cars.is_empty():
		fail("no TrafficCar in group 'traffic_car'")
	elif not all_glb:
		fail("not all cars use car.glb")
	metrics["pass"] = failures.is_empty()


## dot(visual facing, horizontal normalized velocity); -2 when undefined.
func _facing_dot(body: Node3D, vel: Vector3) -> float:
	var hv: Vector3 = Vector3(vel.x, 0.0, vel.z)
	if hv.length() < 0.1:
		fail("%s horizontal speed too low to measure facing" % body.name)
		return -2.0
	var vis: Node = _find_visual(body)
	if vis == null:
		fail("%s has no visual with get_facing_dir()" % body.name)
		return -2.0
	var f: Vector3 = vis.call("get_facing_dir") as Vector3
	return f.dot(hv.normalized())


func _find_visual(n: Node) -> Node:
	for c: Node in n.get_children():
		if c.has_method("get_facing_dir"):
			return c
		var r: Node = _find_visual(c)
		if r != null:
			return r
	return null
