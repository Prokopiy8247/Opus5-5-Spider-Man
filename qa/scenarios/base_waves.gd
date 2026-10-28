extends "res://qa/scenarios/qa_scenario.gd"
## Calls EnemyBase.raise_alarm(), then expects 3 wave_started and base_cleared
## within 300 s. Enemies are defeated through Enemy.take_hit to keep it fast.

const TIME_LIMIT_S: float = 300.0

var waves: Array[int] = []
var cleared: bool = false


func run() -> void:
	var p: Node3D = await wait_player()
	if p == null:
		return
	var ev: Node = get_autoload("Events")
	if ev == null or not ev.has_signal("wave_started") or not ev.has_signal("base_cleared"):
		fail("Events.wave_started / base_cleared missing")
		return
	await seconds(1.0)
	var base: Node3D = nearest_base(p.global_position)
	if base == null:
		fail("no node in group 'enemy_base'")
		return
	var bid: StringName = StringName(str(base.get("base_id")))
	metrics["base_id"] = String(bid)
	ev.connect("wave_started", func(id: StringName, w: int) -> void:
		if id == bid:
			waves.append(w))
	ev.connect("base_cleared", func(id: StringName) -> void:
		if id == bid:
			cleared = true)
	var gs: Node = get_autoload("GameState")
	var xp0: int = int(gs.get("xp")) if gs != null else 0
	if p.has_method("teleport"):
		p.call("teleport", base.global_position + Vector3(0, 30, 0))
	base.call("raise_alarm")
	var t0: int = Time.get_ticks_msec()
	while not cleared and float(Time.get_ticks_msec() - t0) / 1000.0 < TIME_LIMIT_S:
		await seconds(0.5)
		_defeat_near(base.global_position)
	metrics["waves"] = waves
	metrics["cleared"] = cleared
	metrics["is_cleared"] = bool(base.call("is_cleared"))
	metrics["clear_time_s"] = snappedf(float(Time.get_ticks_msec() - t0) / 1000.0, 0.1)
	metrics["xp_reward"] = (int(gs.get("xp")) - xp0) if gs != null else 0
	await screenshot("cleared")
	if waves.size() < 3:
		fail("only %d wave_started events (%s)" % [waves.size(), str(waves)])
	if not cleared:
		fail("base_cleared not emitted within %.0f s" % TIME_LIMIT_S)


## Knocks out live enemies within 150 m of the base.
func _defeat_near(c: Vector3) -> void:
	for n: Node in get_tree().get_nodes_in_group("enemy"):
		var e: Node3D = n as Node3D
		if e == null or bool(e.get("dead")) or e.global_position.distance_to(c) > 150.0:
			continue
		if e.has_method("take_hit"):
			e.call("take_hit", 9999.0, Vector3.FORWARD, &"qa")
