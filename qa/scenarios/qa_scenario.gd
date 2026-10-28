extends Node
## Base class for QA scenarios. Subclasses override run() (a coroutine) and
## use the helpers. The lead's contract does not pin metrics.json fields, so
## every scenario writes this common schema plus scenario-specific keys:
##   scenario:String, pass:bool, failures:Array[String], duration_s:float,
##   started_at:String (ISO), godot_version:String, avg_fps:float,
##   screenshots:Array[String], bugs:Array[{severity, text}]

## Scenarios added after qa_runner.gd's table. qa_runner falls back to this base
## script for unknown names; begin() then delegates to the registered script.
const EXTRA_SCENARIOS: Dictionary = {
	"gadget_bot": "res://qa/scenarios/gadget_bot.gd",
	"progression_bot": "res://qa/scenarios/progression_bot.gd",
	"stealth_bot": "res://qa/scenarios/stealth_bot.gd",
	"base_waves": "res://qa/scenarios/base_waves.gd",
	"menu_bot": "res://qa/scenarios/menu_bot.gd",
	"damage_bot": "res://qa/scenarios/damage_bot.gd",
	"world_stream_bot": "res://qa/scenarios/world_stream_bot.gd",
	"facing_bot": "res://qa/scenarios/facing_bot.gd",
	"car_model_bot": "res://qa/scenarios/car_model_bot.gd",
	"ko_bot": "res://qa/scenarios/ko_bot.gd",
	"street_bot": "res://qa/scenarios/street_bot.gd",
	"park_bot": "res://qa/scenarios/park_bot.gd",
	"prop_gallery": "res://qa/scenarios/prop_gallery.gd",
	"material_bot": "res://qa/scenarios/material_bot.gd",
	"before_set": "res://qa/scenarios/before_set.gd",
	"building_gallery": "res://qa/scenarios/building_gallery.gd",
	"facade_bot": "res://qa/scenarios/facade_bot.gd",
}
const BASE_PATH: String = "res://qa/scenarios/qa_scenario.gd"

var scenario_name: String = ""
var metrics: Dictionary = {}
var failures: Array[String] = []
var bugs: Array[Dictionary] = []
var screenshots: Array[String] = []
var _t0_ms: int = 0
var _fps_sum: float = 0.0
var _fps_n: int = 0
var _finished: bool = false
var evidence_dir: String = ""
## false when run as a sub-scenario (regression): finish() writes metrics but does not quit.
var standalone: bool = true
var result_pass: bool = false
## Optional screenshot folder (absolute); metrics.json still goes to evidence_dir.
var shot_dir: String = ""


## Free QA camera used by the building scenarios (current camera while they run).
func make_qa_camera(parent: Node) -> Camera3D:
	var cam := Camera3D.new()
	cam.name = "QACamera"
	cam.fov = 70.0
	cam.far = 4000.0
	parent.add_child(cam)
	cam.make_current()
	return cam


## Moves the player to the look target (so chunks stream in around it), then places the camera.
func place_cam(cam: Camera3D, p: Node3D, pos: Vector3, target: Vector3, settle_s: float = 1.0) -> void:
	if p != null and p.has_method("teleport"):
		p.call("teleport", Vector3(target.x, maxf(target.y, 1.0), target.z))
	cam.global_position = pos
	if pos.distance_to(target) > 0.01:
		var up: Vector3 = Vector3.UP if absf((target - pos).normalized().y) < 0.99 else Vector3.FORWARD
		cam.look_at(target, up)
	cam.make_current()
	await seconds(settle_s)


## Returns true when the scenario passed.
func begin(p_name: String) -> bool:
	var me: Script = get_script() as Script
	if me != null and me.resource_path == BASE_PATH and EXTRA_SCENARIOS.has(p_name):
		var s: Script = load(String(EXTRA_SCENARIOS[p_name])) as Script
		var real: Node = s.new() as Node
		real.name = "QAScenario_" + p_name
		real.set("standalone", standalone)
		get_parent().add_child(real)
		var ok: bool = await real.call("begin", p_name)
		_finished = true
		queue_free()
		return ok
	scenario_name = p_name
	_t0_ms = Time.get_ticks_msec()
	evidence_dir = ProjectSettings.globalize_path("res://qa/evidence/%s" % scenario_name)
	DirAccess.make_dir_recursive_absolute(evidence_dir)
	print("[QA] scenario %s started" % scenario_name)
	await run()
	finish()
	return result_pass


## Override in subclasses.
func run() -> void:
	await frames(2)


func _process(_delta: float) -> void:
	_fps_sum += Engine.get_frames_per_second()
	_fps_n += 1


# ---------------------------------------------------------------- helpers

func elapsed_s() -> float:
	return float(Time.get_ticks_msec() - _t0_ms) / 1000.0


func frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func seconds(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func fail(reason: String) -> void:
	failures.append(reason)
	# print, not push_error: QA failures go to metrics.json, the log stays clean.
	print("[QA] FAIL: " + reason)


func bug(severity: String, text: String) -> void:
	bugs.append({"severity": severity, "text": text})
	print("[QA] BUG %s: %s" % [severity, text])
	if severity == "P0" or severity == "P1":
		fail(text)


func screenshot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var tex: ViewportTexture = get_viewport().get_texture()
	var img: Image = tex.get_image() if tex != null else null
	if img == null or img.is_empty():
		print("[QA] screenshot '%s' skipped (no image, headless?)" % label)
		return
	var dir: String = shot_dir if shot_dir != "" else evidence_dir
	var file: String = "%s/%02d_%s.png" % [dir, screenshots.size(), label]
	if img.save_png(file) == OK:
		screenshots.append(file.get_file())


func get_player() -> Node3D:
	return get_tree().get_first_node_in_group("player") as Node3D


func get_world() -> Node:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return null
	if scene.has_method("get_spawn_transform"):
		return scene
	return _find_with_method(scene, "get_spawn_transform")


func _find_with_method(n: Node, m: String) -> Node:
	for c: Node in n.get_children():
		if c.has_method(m):
			return c
		var r: Node = _find_with_method(c, m)
		if r != null:
			return r
	return null


## Waits up to timeout_s for the player to exist.
func wait_player(timeout_s: float = 15.0) -> Node3D:
	var t: float = 0.0
	while t < timeout_s:
		var p: Node3D = get_player()
		if p != null:
			return p
		await get_tree().process_frame
		t += get_process_delta_time()
	fail("player (group 'player') not found within %.0f s" % timeout_s)
	return null


func bot(p: Node, move: Vector2, actions: Dictionary) -> void:
	if p != null and p.has_method("set_bot_input"):
		p.call("set_bot_input", move, actions)


func player_velocity(p: Node3D) -> Vector3:
	if p.has_method("get_velocity_world"):
		return p.call("get_velocity_world") as Vector3
	return Vector3.ZERO


func player_state(p: Node) -> StringName:
	if p.has_method("get_state"):
		return p.call("get_state") as StringName
	return &""


func get_autoload(n: String) -> Node:
	return get_node_or_null("/root/" + n)


## Waits until cond returns true or timeout; returns whether it became true.
func wait_until(cond: Callable, timeout_s: float) -> bool:
	var t0: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - t0) / 1000.0 < timeout_s:
		if bool(cond.call()):
			return true
		await get_tree().physics_frame
	return bool(cond.call())


## Nearest node in group "enemy_base" to pos (or null).
func nearest_base(pos: Vector3) -> Node3D:
	var best: Node3D = null
	var bd: float = INF
	for n: Node in get_tree().get_nodes_in_group("enemy_base"):
		var b: Node3D = n as Node3D
		if b == null:
			continue
		var d: float = b.global_position.distance_squared_to(pos)
		if d < bd:
			bd = d
			best = b
	return best


func perf_snapshot() -> Dictionary:
	return {
		"fps": Engine.get_frames_per_second(),
		"draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"objects": Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME),
		"static_mem_mb": Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0,
		"video_mem_mb": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0,
		"nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
	}


## Swing-traversal driver shared by traversal_bot / city_flythrough / regression / soak10.
## Holds forward + swing, releases near the arc top (vy turns <= 0 after rising,
## or after max hold), re-attaches after a short gap. Tracks stuck time and min y.
## stop_distance <= 0 means "run for duration_s".
## turn_every_s > 0 makes the bot steer left/right periodically (random grid route).
func drive_swing(p: Node3D, duration_s: float, stop_distance: float = 0.0,
		turn_every_s: float = 0.0, shot_every_s: float = 0.0) -> Dictionary:
	var st: Dictionary = {
		"swings": 0, "distance_m": 0.0, "max_stuck_s": 0.0, "min_y": INF,
		"time_to_target_s": -1.0, "max_speed": 0.0, "avg_speed": 0.0,
		"max_chain": 0, "unstuck_calls": 0,
	}
	if p == null:
		return st
	var swings: Array[int] = [0]
	var cb: Callable = func(_a: Vector3, _h: StringName) -> void: swings[0] += 1
	var ev: Node = get_node_or_null("/root/Events")
	if ev != null and ev.has_signal("web_attached"):
		ev.connect("web_attached", cb)
	var start: Vector3 = p.global_position
	var t: float = 0.0
	var hold: bool = false
	var hold_t: float = 0.0
	var gap_t: float = 0.0
	var rising: bool = false
	var stuck_t: float = 0.0
	var speed_sum: float = 0.0
	var n: int = 0
	var steer: float = 0.0
	var steer_t: float = 0.0
	var shot_t: float = 0.0
	var chain: int = 0
	var last_swings: int = 0
	var grounded_t: float = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337
	# Kick off: jump from the roof.
	bot(p, Vector2(0, 1), {"jump": true})
	await get_tree().physics_frame
	bot(p, Vector2(0, 1), {})
	while t < duration_s:
		await get_tree().physics_frame
		var dt: float = get_physics_process_delta_time()
		t += dt
		if not is_instance_valid(p):
			bug("P0", "player freed during traversal")
			break
		var v: Vector3 = player_velocity(p)
		var hv: float = Vector2(v.x, v.z).length()
		var s: StringName = player_state(p)
		var on_floor: bool = (p as CharacterBody3D).is_on_floor() if p is CharacterBody3D else false
		var airborne: bool = s != &"grounded" and not on_floor
		# swing control
		if hold:
			hold_t += dt
			if v.y > 1.0:
				rising = true
			var top: bool = rising and v.y <= 0.5
			if top or hold_t > 2.2 or (s != &"swinging" and hold_t > 0.6 and s != &""):
				hold = false
				gap_t = 0.0
		else:
			gap_t += dt
			if gap_t > 0.2 and airborne:
				hold = true
				hold_t = 0.0
				rising = false
		var actions: Dictionary = {"swing": hold}
		if not airborne:
			grounded_t += dt
			if grounded_t > 0.5:
				actions["jump"] = true
				grounded_t = 0.0
		else:
			grounded_t = 0.0
		if turn_every_s > 0.0:
			steer_t += dt
			if steer_t > turn_every_s:
				steer_t = 0.0
				steer = [-1.0, 0.0, 0.0, 1.0][rng.randi_range(0, 3)]
		bot(p, Vector2(steer, 1.0).limit_length(1.0), actions)
		# chain of swings without touching ground
		if swings[0] != last_swings:
			chain += 1
			last_swings = swings[0]
			st["max_chain"] = maxi(int(st["max_chain"]), chain)
		if s == &"grounded":
			chain = 0
		# metrics
		var pos: Vector3 = p.global_position
		st["min_y"] = minf(float(st["min_y"]), pos.y)
		var d: float = Vector2(pos.x - start.x, pos.z - start.z).length()
		st["distance_m"] = maxf(float(st["distance_m"]), d)
		st["max_speed"] = maxf(float(st["max_speed"]), v.length())
		speed_sum += v.length()
		n += 1
		if v.length() < 0.3:
			stuck_t += dt
			st["max_stuck_s"] = maxf(float(st["max_stuck_s"]), stuck_t)
		else:
			stuck_t = 0.0
		if pos.y < -50.0:
			bug("P0", "player fell below y=-50 at t=%.1f s (%.0f, %.0f, %.0f)" % [t, pos.x, pos.y, pos.z])
			break
		if shot_every_s > 0.0:
			shot_t += dt
			if shot_t > shot_every_s and s == &"swinging":
				shot_t = 0.0
				await screenshot("swing_t%03d" % int(t))
		if stop_distance > 0.0 and d >= stop_distance:
			st["time_to_target_s"] = snappedf(t, 0.01)
			break
	bot(p, Vector2.ZERO, {})
	if ev != null and ev.is_connected("web_attached", cb):
		ev.disconnect("web_attached", cb)
	st["swings"] = swings[0]
	st["avg_speed"] = snappedf(speed_sum / maxf(1.0, float(n)), 0.01)
	st["distance_m"] = snappedf(float(st["distance_m"]), 0.1)
	st["max_stuck_s"] = snappedf(float(st["max_stuck_s"]), 0.01)
	st["min_y"] = snappedf(float(st["min_y"]), 0.01) if st["min_y"] != INF else 0.0
	st["elapsed_s"] = snappedf(t, 0.01)
	return st


func finish() -> void:
	if _finished:
		return
	_finished = true
	var out: Dictionary = metrics.duplicate()
	out["scenario"] = scenario_name
	out["pass"] = failures.is_empty() and bool(metrics.get("pass", true))
	out["failures"] = failures
	out["bugs"] = bugs
	out["duration_s"] = snappedf(elapsed_s(), 0.01)
	out["started_at"] = Time.get_datetime_string_from_system(false, true)
	out["godot_version"] = Engine.get_version_info().get("string", "")
	out["avg_fps"] = snappedf(_fps_sum / maxf(1.0, float(_fps_n)), 0.1)
	out["screenshots"] = screenshots
	var f: FileAccess = FileAccess.open(evidence_dir + "/metrics.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "  "))
		f.close()
	var ok: bool = out["pass"]
	result_pass = ok
	print("[QA] scenario %s %s" % [scenario_name, "PASS" if ok else "FAIL"])
	if not standalone:
		return
	# Deferred so the begin()/run() coroutines finish first; quitting mid-await leaks their states.
	get_tree().quit.call_deferred(0 if ok else 1)
