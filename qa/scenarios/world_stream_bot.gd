extends "res://qa/scenarios/qa_scenario.gd"
## Finds TrafficManager ("traffic_manager") and ChunkStreamer ("chunk_streamer"),
## moves the player across the city in steps and checks car count and the 5x5 chunk window.

const STEP_M: float = 160.0
const STEPS: int = 8

var checks: Dictionary = {}


func run() -> void:
	var p: Node3D = await wait_player()
	if p == null:
		return
	await seconds(1.0)
	var tm: Node = get_tree().get_first_node_in_group("traffic_manager")
	var cs: Node = get_tree().get_first_node_in_group("chunk_streamer")
	checks["traffic_manager_found"] = tm != null
	checks["chunk_streamer_found"] = cs != null
	if tm == null or cs == null:
		_flush()
		return
	var start: Vector3 = p.global_position
	var max_loaded: int = 0
	var min_cars: int = 1 << 30
	var total: int = int(cs.call("get_total_chunk_count"))
	var around_ok: bool = true
	var samples: Array[Dictionary] = []
	for i: int in STEPS + 1:
		# Diagonal route; teleport keeps the run deterministic and fast.
		var pos: Vector3 = start + Vector3(STEP_M * float(i) * 0.7, 0.0, STEP_M * float(i) * 0.7)
		if i > 0 and p.has_method("teleport"):
			p.call("teleport", pos)
		await seconds(1.0)
		var loaded: int = int(cs.call("get_loaded_chunk_count"))
		var cars: int = int(tm.call("get_active_car_count"))
		var c: Vector2i = cs.call("chunk_of", p.global_position) as Vector2i
		var here: bool = bool(cs.call("is_chunk_loaded", c))
		max_loaded = maxi(max_loaded, loaded)
		min_cars = mini(min_cars, cars)
		around_ok = around_ok and here
		samples.append({"step": i, "chunk": str(c), "loaded": loaded, "cars": cars, "player_chunk_loaded": here})
		if i == 0 or i == STEPS:
			await screenshot("stream_step%02d" % i)
	total = int(cs.call("get_total_chunk_count"))
	metrics["samples"] = samples
	metrics["active_cars_min"] = min_cars
	metrics["loaded_chunks_max"] = max_loaded
	metrics["total_chunks"] = total
	checks["cars_active"] = min_cars > 0
	checks["loaded_le_25"] = max_loaded <= 25
	checks["total_gt_25"] = total > 25
	checks["player_chunk_loaded"] = around_ok
	_flush()


func _flush() -> void:
	metrics["checks"] = checks
	for k: String in checks:
		if not bool(checks[k]):
			fail("check failed: " + k)
