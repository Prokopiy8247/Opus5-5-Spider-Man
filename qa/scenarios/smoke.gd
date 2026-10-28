extends "res://qa/scenarios/qa_scenario.gd"
## Smoke: main scene boots, player + world exist, a few seconds run, screenshot.

func run() -> void:
	var t_start: float = elapsed_s()
	var p: Node3D = await wait_player(20.0)
	metrics["startup_s"] = snappedf(elapsed_s() - t_start, 0.01)
	metrics["player_found"] = p != null
	metrics["world_found"] = get_world() != null
	await seconds(3.0)
	if p != null:
		metrics["player_state"] = String(player_state(p))
		metrics["player_pos"] = [p.global_position.x, p.global_position.y, p.global_position.z]
		if p.global_position.y < -50.0:
			bug("P0", "player below y=-50 after spawn")
	metrics.merge(perf_snapshot())
	await screenshot("spawn")
