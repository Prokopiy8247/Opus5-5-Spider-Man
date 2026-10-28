extends "res://qa/scenarios/qa_scenario.gd"
## 3 minutes of swinging with random turns. Stuck (speed~0 >2 s with input) = P1, y<-50 = P0.

func run() -> void:
	var p: Node3D = await wait_player()
	if p == null:
		return
	await seconds(1.0)
	var st: Dictionary = await drive_swing(p, 180.0, 0.0, 4.0, 20.0)
	metrics.merge(st, true)
	if float(st["max_stuck_s"]) > 2.0:
		bug("P1", "stuck for %.1f s with input held" % float(st["max_stuck_s"]))
	metrics.merge(perf_snapshot())
	await screenshot("end")
