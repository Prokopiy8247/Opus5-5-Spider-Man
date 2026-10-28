extends "res://qa/scenarios/qa_scenario.gd"
## 10-minute random-route soak: stuck/fall detection, memory leak check.
## Leak = static memory grew >25% between minute 1 and minute 10 (P1).

func run() -> void:
	var p: Node3D = await wait_player()
	if p == null:
		return
	await seconds(1.0)
	var mem: Array[float] = []
	var total_swings: int = 0
	var max_stuck: float = 0.0
	var min_y: float = INF
	var dist: float = 0.0
	for minute: int in 10:
		var st: Dictionary = await drive_swing(p, 60.0, 0.0, 3.0 + float(minute % 3), 0.0)
		total_swings += int(st["swings"])
		max_stuck = maxf(max_stuck, float(st["max_stuck_s"]))
		min_y = minf(min_y, float(st["min_y"]))
		dist += float(st["distance_m"])
		mem.append(snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1))
		await screenshot("minute_%02d" % (minute + 1))
		if not failures.is_empty() or not is_instance_valid(p):
			break
		if float(st["max_stuck_s"]) > 2.0 and p.has_method("unstuck"):
			p.call("unstuck")
	metrics["swings"] = total_swings
	metrics["max_stuck_s"] = max_stuck
	metrics["min_y"] = min_y if min_y != INF else 0.0
	metrics["distance_m"] = snappedf(dist, 0.1)
	metrics["static_mem_mb_per_min"] = mem
	if max_stuck > 2.0:
		bug("P1", "stuck %.1f s during soak" % max_stuck)
	if mem.size() >= 10 and mem[9] > mem[0] * 1.25:
		bug("P1", "memory grew %.1f -> %.1f MB" % [mem[0], mem[9]])
	metrics.merge(perf_snapshot(), false)
