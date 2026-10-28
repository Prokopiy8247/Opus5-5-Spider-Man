class_name TrafficManager
extends Node3D
## Spawns up to max_cars TrafficCar nodes on closed lanes, moves them every physics frame,
## stops cars that have the player or another car within 6 m ahead, and keeps cars within
## FOCUS_RADIUS of the focus point by relocating far ones closer.

const FOCUS_RADIUS: float = 300.0
const RESPAWN_MIN: float = 40.0
const RESPAWN_MAX: float = 250.0

var _lanes: Array[PackedVector3Array] = []
var _cum: Array[PackedFloat32Array] = []
var _len: PackedFloat32Array = PackedFloat32Array()
var _cars: Array[TrafficCar] = []
var _focus: Vector3 = Vector3.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _relocate_timer: float = 0.0


func _ready() -> void:
	add_to_group(&"traffic_manager")
	_rng.seed = 4242


func setup(lanes: Array[PackedVector3Array], max_cars: int = 40) -> void:
	for c: TrafficCar in _cars:
		c.queue_free()
	_cars.clear()
	_lanes.clear()
	_cum.clear()
	_len.clear()
	for l: PackedVector3Array in lanes:
		if l.size() < 2 or _near_park(l):
			continue
		var cum: PackedFloat32Array = PackedFloat32Array()
		var t: float = 0.0
		for i: int in l.size():
			cum.append(t)
			t += l[i].distance_to(l[(i + 1) % l.size()])
		if t < 1.0:
			continue
		_lanes.append(l)
		_cum.append(cum)
		_len.append(t)
	if _lanes.is_empty() or max_cars <= 0:
		return
	for i: int in max_cars:
		var car: TrafficCar = TrafficCar.new()
		car.name = "TrafficCar_%d" % i
		car.cruise_speed = _rng.randf_range(TrafficCar.MIN_SPEED, TrafficCar.MAX_SPEED)
		car.build(i)
		add_child(car)
		_place_near(car, _focus)


## Stop lines from World.get_stop_lines(): {"pos","dir","light_id"}, bucketed by lane z.
var _stops: Dictionary = {}  # int(round z) -> Array
const STOP_LOOKAHEAD: float = 9.0


func set_stop_lines(lines: Array[Dictionary]) -> void:
	_stops.clear()
	for s: Dictionary in lines:
		var k: int = roundi((s["pos"] as Vector3).z)
		if not _stops.has(k):
			_stops[k] = []
		(_stops[k] as Array).append(s)


## True when a red (or early yellow) stop line is 0..STOP_LOOKAHEAD m ahead of the front bumper.
func _red_ahead(c: TrafficCar) -> bool:
	var arr: Array = _stops.get(roundi(c.global_position.z), []) as Array
	if arr.is_empty():
		return false
	var f: Vector3 = c.forward_dir()
	for s: Dictionary in arr:
		var dir: Vector3 = s["dir"]
		if f.dot(dir) < 0.9:
			continue
		var ahead: float = ((s["pos"] as Vector3) - c.global_position).dot(dir) - 2.3
		if ahead < 0.0 or ahead > STOP_LOOKAHEAD:
			continue
		var st: StringName = TrafficLights.state(int(s["light_id"]))
		if st == &"red" or (st == &"yellow" and ahead > 3.0):
			return true
	return false


## Lanes are closed polylines of axis-aligned segments; reject any lane whose segment comes
## within PARK_CLEARANCE of CityGrid.PARK_RECT (World supplies re-routed lanes that pass).
const PARK_CLEARANCE: float = 2.0


static func _near_park(l: PackedVector3Array) -> bool:
	var r: Rect2 = CityGrid.PARK_RECT.grow(PARK_CLEARANCE)
	for i: int in l.size():
		var a: Vector3 = l[i]
		var b: Vector3 = l[(i + 1) % l.size()]
		var seg: Rect2 = Rect2(Vector2(minf(a.x, b.x), minf(a.z, b.z)), Vector2(absf(a.x - b.x), absf(a.z - b.z)))
		if seg.grow(0.01).intersects(r):
			print("[TrafficManager] lane rejected: too close to the park")
			return true
	return false


func get_active_car_count() -> int:
	return _cars.size()


func set_focus(pos: Vector3) -> void:
	_focus = pos
	for c: TrafficCar in _cars:
		var d: Vector3 = c.global_position - pos
		d.y = 0.0
		if d.length() > FOCUS_RADIUS:
			_place_near(c, pos)


func _physics_process(delta: float) -> void:
	if _cars.is_empty():
		return
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	var ppos: Vector3 = player.global_position if player != null else Vector3.INF
	for c: TrafficCar in _cars:
		var blocked: bool = ppos != Vector3.INF and absf(ppos.y - c.global_position.y) < 3.0 and c.is_blocking(ppos)
		if not blocked:
			for o: TrafficCar in _cars:
				if o != c and c.is_blocking(o.global_position):
					blocked = true
					break
		if not blocked:
			blocked = _red_ahead(c)
		c.advance(delta, blocked)
	_relocate_timer -= delta
	if _relocate_timer <= 0.0:
		_relocate_timer = 1.0
		if player != null:
			set_focus(player.global_position)
		else:
			set_focus(_focus)


## Puts a car on the lane point nearest to a random spot around `pos` (40..250 m away),
## avoiding spots occupied by another car.
func _place_near(car: TrafficCar, pos: Vector3) -> void:
	if car.get_parent() == null:
		return
	for attempt: int in 8:
		var a: float = _rng.randf() * TAU
		var r: float = _rng.randf_range(RESPAWN_MIN, RESPAWN_MAX)
		var target: Vector3 = pos + Vector3(cos(a), 0.0, sin(a)) * r
		var best_l: int = 0
		var best_s: float = 0.0
		var best_d: float = INF
		for li: int in _lanes.size():
			var l: PackedVector3Array = _lanes[li]
			for i: int in l.size():
				var p0: Vector3 = l[i]
				var p1: Vector3 = l[(i + 1) % l.size()]
				var seg: Vector3 = p1 - p0
				var sl: float = seg.length()
				if sl < 0.001:
					continue
				var t: float = clampf((target - p0).dot(seg) / (sl * sl), 0.0, 1.0)
				var q: Vector3 = p0 + seg * t
				var dd: float = Vector2(q.x - target.x, q.z - target.z).length()
				if dd < best_d:
					best_d = dd
					best_l = li
					best_s = _cum[li][i] + sl * t
		car.assign_lane(best_l, _lanes[best_l], _cum[best_l], _len[best_l], best_s)
		var free: bool = true
		for o: TrafficCar in _cars:
			if o != car and o.global_position.distance_to(car.global_position) < 10.0:
				free = false
				break
		if free or attempt == 7:
			break
	if not _cars.has(car):
		_cars.append(car)
