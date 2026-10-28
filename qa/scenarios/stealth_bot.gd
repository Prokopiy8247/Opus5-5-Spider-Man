extends "res://qa/scenarios/qa_scenario.gd"
## Approaches an enemy base while staying outside the detection radius.
## Pass: Events.base_alarm is never emitted.

## Enemy vision in scripts/ai/enemy.gd is 30 m; stay well outside it.
const SAFE_DIST: float = 45.0

var alarms: int = 0


func run() -> void:
	var p: Node3D = await wait_player()
	if p == null:
		return
	var ev: Node = get_autoload("Events")
	if ev == null or not ev.has_signal("base_alarm"):
		fail("Events.base_alarm signal missing")
		return
	ev.connect("base_alarm", func(_id: StringName) -> void: alarms += 1)
	await seconds(1.0)
	var base: Node3D = nearest_base(p.global_position)
	if base == null:
		fail("no node in group 'enemy_base'")
		return
	metrics["base_id"] = String(base.get("base_id"))
	# Start 120 m out on the ground, walk in to SAFE_DIST.
	var center: Vector3 = base.global_position
	var dir: Vector3 = Vector3(1, 0, 0.3).normalized()
	if p.has_method("teleport"):
		p.call("teleport", center + dir * 120.0 + Vector3.UP * 2.0)
	await seconds(1.0)
	var min_d: float = INF
	var t: float = 0.0
	while t < 40.0 and is_instance_valid(p):
		await get_tree().physics_frame
		t += get_physics_process_delta_time()
		var flat: Vector3 = Vector3(center.x - p.global_position.x, 0, center.z - p.global_position.z)
		var d: float = flat.length()
		min_d = minf(min_d, d)
		if d <= SAFE_DIST:
			break
		# Steer directly: teleport-step instead of relying on camera-relative input.
		p.call("teleport", p.global_position + flat.normalized() * 6.0 * get_physics_process_delta_time())
		bot(p, Vector2.ZERO, {})
	bot(p, Vector2.ZERO, {})
	# Linger at the edge.
	await seconds(5.0)
	await screenshot("edge")
	metrics["closest_m"] = snappedf(min_d, 0.1)
	metrics["alarms"] = alarms
	if min_d > SAFE_DIST + 5.0:
		fail("did not reach the base edge (closest %.1f m)" % min_d)
	if alarms > 0:
		fail("base_alarm emitted %d times while outside detection radius" % alarms)
