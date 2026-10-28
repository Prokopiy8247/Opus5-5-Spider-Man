extends "res://qa/scenarios/qa_scenario.gd"
## Runs scenarios back to back in one session. Each sub-scenario writes its own
## qa/evidence/<name>/metrics.json (standalone=false, so it does not quit);
## regression/metrics.json lists per-scenario pass and fails if any failed.
## Excluded: regression (self), soak10 (10 min), load_all/perf_sweep/city_flythrough
## (long or scene-switching; run them separately via run_all.ps1).

const SEQUENCE: Array[String] = [
	"smoke", "traversal_bot", "combat_bot", "animation_gallery",
	"gadget_bot", "progression_bot", "stealth_bot", "base_waves",
]
const SCRIPTS: Dictionary = {
	"smoke": "res://qa/scenarios/smoke.gd",
	"traversal_bot": "res://qa/scenarios/traversal_bot.gd",
	"combat_bot": "res://qa/scenarios/combat_bot.gd",
	"animation_gallery": "res://qa/scenarios/animation_gallery.gd",
	"gadget_bot": "res://qa/scenarios/gadget_bot.gd",
	"progression_bot": "res://qa/scenarios/progression_bot.gd",
	"stealth_bot": "res://qa/scenarios/stealth_bot.gd",
	"base_waves": "res://qa/scenarios/base_waves.gd",
}


func run() -> void:
	var p: Node3D = await wait_player()
	if p == null:
		return
	await seconds(1.0)
	var results: Array[Dictionary] = []
	for s_name: String in SEQUENCE:
		var t0: int = Time.get_ticks_msec()
		var script: Script = load(String(SCRIPTS[s_name])) as Script
		var ok: bool = false
		if script == null:
			fail("%s: script failed to load" % s_name)
		else:
			var sub: Node = script.new() as Node
			sub.name = "Sub_" + s_name
			sub.set("standalone", false)
			add_child(sub)
			ok = bool(await sub.call("begin", s_name))
			sub.queue_free()
			await frames(2)
		var dur: float = snappedf(float(Time.get_ticks_msec() - t0) / 1000.0, 0.01)
		results.append({"scenario": s_name, "pass": ok, "duration_s": dur})
		print("[QA] regression: %s %s (%.1f s)" % [s_name, "PASS" if ok else "FAIL", dur])
		if not ok:
			fail("sub-scenario %s failed" % s_name)
		# Reset player between scenarios.
		p = get_player()
		if p != null:
			bot(p, Vector2.ZERO, {})
			var w: Node = get_world()
			if w != null and w.has_method("get_spawn_transform") and p.has_method("teleport"):
				var tr: Transform3D = w.call("get_spawn_transform") as Transform3D
				p.call("teleport", tr.origin)
		await seconds(0.5)
	metrics["results"] = results
	metrics["passed"] = results.filter(func(r: Dictionary) -> bool: return bool(r["pass"])).size()
	metrics["total"] = results.size()
