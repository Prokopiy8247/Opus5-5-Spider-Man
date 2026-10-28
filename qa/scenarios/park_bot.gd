extends "res://qa/scenarios/qa_scenario.gd"
## Park review: aerial view, 3 ground views, a swing across the park on 'anchorable'
## tree canopies, and a 10-minute traffic simulation (Engine.time_scale = 4 -> 150 s wall)
## asserting no TrafficCar (group 'traffic_car') is ever inside World.get_park_rect().

const SIM_GAME_S: float = 600.0
const SIM_SCALE: float = 4.0

var _cam: Camera3D
var _prev_cam: Camera3D


func run() -> void:
	var p: Node3D = await wait_player()
	if p == null:
		return
	var w: Node = get_world()
	if w == null or not w.has_method("get_park_rect"):
		fail("World.get_park_rect() missing")
		return
	var r: Rect2 = w.call("get_park_rect") as Rect2
	metrics["park_rect"] = [r.position.x, r.position.y, r.size.x, r.size.y]
	var c: Vector3 = Vector3(r.get_center().x, 0.0, r.get_center().y)
	if w.has_method("set_time_of_day"):
		w.call("set_time_of_day", 13.0)
	if p.has_method("teleport"):
		p.call("teleport", w.call("teleport_point", &"park") as Vector3)
	var tp: Vector3 = w.call("teleport_point", &"park") as Vector3
	metrics["teleport_on_path_y"] = tp.y
	await seconds(2.0)
	# --- views
	_prev_cam = get_viewport().get_camera_3d()
	_cam = Camera3D.new()
	_cam.far = 2000.0
	get_tree().current_scene.add_child(_cam)
	_cam.current = true
	var span: float = maxf(r.size.x, r.size.y)
	await _view(c + Vector3(0, span * 0.9, span * 0.35), c, "aerial")
	var views: Array = [
		[Vector3(r.position.x + 25, 1.7, r.position.y + 25), c],
		[Vector3(r.end.x - 25, 1.7, c.z), c],
		[Vector3(c.x, 1.7, r.end.y - 20), c + Vector3(0, 0, -40)],
	]
	for i: int in views.size():
		await _view(views[i][0] as Vector3, views[i][1] as Vector3, "ground_%d" % i)
	_cam.current = false
	if is_instance_valid(_prev_cam):
		_prev_cam.current = true
	_cam.queue_free()
	# --- anchors
	var trees: int = 0
	for n: Node in get_tree().get_nodes_in_group("anchorable"):
		var a: Node3D = n as Node3D
		if a == null:
			continue
		var ap: Vector3 = a.get_meta("anchor_point", a.global_position) as Vector3
		if r.has_point(Vector2(ap.x, ap.z)):
			trees += 1
	metrics["park_anchors"] = trees
	if trees < 50:
		fail("only %d anchorable points inside the park" % trees)
	# --- swing across (west -> east along the centre line)
	if p.has_method("teleport"):
		p.call("teleport", Vector3(r.position.x + 5.0, 14.0, c.z))
	p.look_at(Vector3(r.end.x, 14.0, c.z), Vector3.UP)
	await frames(3)
	var swings: Array[int] = [0]
	var in_park: Array[int] = [0]
	var ev: Node = get_autoload("Events")
	var cb: Callable = func(at: Vector3, _h: StringName) -> void:
		swings[0] += 1
		if r.has_point(Vector2(at.x, at.z)):
			in_park[0] += 1
	if ev != null and ev.has_signal("web_attached"):
		ev.connect("web_attached", cb)
	var st: Dictionary = await drive_swing(p, 30.0, r.size.x - 10.0, 0.0, 6.0)
	if ev != null and ev.is_connected("web_attached", cb):
		ev.disconnect("web_attached", cb)
	st["attaches_in_park"] = in_park[0]
	metrics["swing"] = st
	if float(st["distance_m"]) < r.size.x * 0.8:
		fail("swing covered %.0f m of %.0f m park width" % [float(st["distance_m"]), r.size.x])
	if in_park[0] < 3:
		fail("only %d web attaches on park anchors" % in_park[0])
	if float(st["min_y"]) < -1.0:
		fail("player fell through park ground (min_y %.2f)" % float(st["min_y"]))
	# --- traffic simulation: player stays in the park centre so traffic streams around it
	if p.has_method("teleport"):
		p.call("teleport", tp)
	var samples: int = 0
	var violations: int = 0
	var max_cars: int = 0
	var worst: Array = []
	Engine.time_scale = SIM_SCALE
	var t0: int = Time.get_ticks_msec()
	var game_t: float = 0.0
	while game_t < SIM_GAME_S:
		await get_tree().create_timer(0.25 * SIM_SCALE, true, false, false).timeout
		game_t = float(Time.get_ticks_msec() - t0) / 1000.0 * SIM_SCALE
		samples += 1
		var cars: Array[Node] = get_tree().get_nodes_in_group("traffic_car")
		max_cars = maxi(max_cars, cars.size())
		for n: Node in cars:
			var car: Node3D = n as Node3D
			if car == null or not car.is_visible_in_tree():
				continue
			if r.has_point(Vector2(car.global_position.x, car.global_position.z)):
				violations += 1
				if worst.size() < 10:
					worst.append([snappedf(game_t, 0.1), car.global_position.x, car.global_position.z])
	Engine.time_scale = 1.0
	metrics["traffic_samples"] = samples
	metrics["traffic_game_s"] = snappedf(game_t, 0.1)
	metrics["max_cars"] = max_cars
	metrics["cars_in_park"] = violations
	metrics["cars_in_park_examples"] = worst
	if max_cars == 0:
		fail("no traffic cars during the simulation")
	if violations > 0:
		fail("%d car samples inside the park" % violations)


func _view(from: Vector3, to: Vector3, label: String) -> void:
	_cam.global_position = from
	_cam.look_at(to, Vector3.UP)
	await frames(10)
	await screenshot(label)
