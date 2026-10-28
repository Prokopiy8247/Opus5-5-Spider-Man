extends "res://qa/scenarios/qa_scenario.gd"
## M1 gate: 20+ swings in a chain along an avenue, 1 km in <= 45 s,
## max_stuck_s < 2, min_y > -50, mid-swing screenshots.

func run() -> void:
	var p: Node3D = await wait_player()
	if p == null:
		return
	await seconds(1.0)
	# Start above the main avenue centre line (World.MAIN_AVE_Z), heading +X.
	if p.has_method("teleport"):
		p.call("teleport", Vector3(p.global_position.x, p.global_position.y + 4.0, -30.0))
		await seconds(0.2)
	# Hold 1 km run, but keep swinging to 60 s so the chain can reach 20.
	var st: Dictionary = await drive_swing(p, 60.0, 1000.0, 0.0, 1.5)
	if int(st["swings"]) < 20:
		# Continue until 20 swings counted (max 30 s more).
		var more: Dictionary = await drive_swing(p, 30.0, 0.0, 0.0, 0.0)
		st["swings"] = int(st["swings"]) + int(more["swings"])
		st["max_stuck_s"] = maxf(float(st["max_stuck_s"]), float(more["max_stuck_s"]))
		st["min_y"] = minf(float(st["min_y"]), float(more["min_y"]))
	metrics.merge(st, true)
	if screenshots.is_empty():
		await screenshot("end")
	var ok: bool = int(st["swings"]) >= 20 \
		and float(st["distance_m"]) >= 1000.0 \
		and float(st["time_to_target_s"]) > 0.0 and float(st["time_to_target_s"]) <= 45.0 \
		and float(st["max_stuck_s"]) < 2.0 and float(st["min_y"]) > -50.0
	if not ok:
		fail("traversal gate not met: %s" % JSON.stringify(st))
	metrics["pass"] = ok
