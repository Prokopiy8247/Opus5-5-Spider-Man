class_name TrafficCar
extends Node3D
## One procedural traffic car following a closed lane (polyline) by arc length.
## Movement is driven by TrafficManager calling advance() each physics frame.

const STOP_DISTANCE: float = 6.0
const LANE_HALF_WIDTH: float = 2.0
const MIN_SPEED: float = 8.0
const MAX_SPEED: float = 14.0

const COLORS: Array[Color] = [
	Color(0.95, 0.78, 0.1), Color(0.75, 0.1, 0.1), Color(0.1, 0.25, 0.7),
	Color(0.9, 0.9, 0.92), Color(0.12, 0.12, 0.14), Color(0.2, 0.55, 0.3),
]

const CAR_MODEL_PATH: String = "res://assets/models/car.glb"
const WHEEL_RADIUS: float = 0.38
const BRAKE_ENERGY_IDLE: float = 1.0
const BRAKE_ENERGY_BRAKING: float = 4.0

static var _car_scene: PackedScene = null
static var _car_scene_checked: bool = false

var lane: PackedVector3Array = PackedVector3Array()
var lane_cum: PackedFloat32Array = PackedFloat32Array()  # cumulative length at each point
var lane_length: float = 0.0
var lane_index: int = -1
var distance: float = 0.0
var cruise_speed: float = 10.0
var current_speed: float = 0.0
var stopped: bool = false
var _wheels: Array[Node3D] = []
var _from_glb: bool = false
var _brake_mat: StandardMaterial3D = null


func _init() -> void:
	add_to_group(&"traffic_car")
	add_to_group(&"stream_always")


## True when this car's visual is the Blender model from car.glb.
func uses_glb_model() -> bool:
	return _from_glb


static func _load_car_scene() -> PackedScene:
	if not _car_scene_checked:
		_car_scene_checked = true
		if ResourceLoader.exists(CAR_MODEL_PATH):
			_car_scene = load(CAR_MODEL_PATH) as PackedScene
	return _car_scene


func build(color_index: int) -> void:
	var color: Color = COLORS[posmod(color_index, COLORS.size())]
	var scene: PackedScene = _load_car_scene()
	if scene != null and _build_from_glb(scene, color):
		return
	_build_procedural(color)


func _build_from_glb(scene: PackedScene, color: Color) -> bool:
	var root: Node3D = scene.instantiate() as Node3D
	if root == null:
		return false
	root.name = "Model"
	add_child(root)
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is Node3D and String(n.name).begins_with("Wheel_"):
			_wheels.append(n as Node3D)
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if String(mi.name).begins_with("Wheel_") \
				else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	# Body colour: multiply the exported (textured) paint material; glass/lights/tyres are skipped.
	StreetBuilder.apply_variant_tint(root, color)
	stack = [root]
	while not stack.is_empty():
		var n2: Node = stack.pop_back()
		stack.append_array(n2.get_children())
		var mi2: MeshInstance3D = n2 as MeshInstance3D
		if mi2 == null or mi2.mesh == null:
			continue
		for s: int in mi2.mesh.get_surface_count():
			var m: Material = mi2.get_active_material(s)
			if m == null or not m.resource_name.begins_with("Car_Brakelight"):
				continue
			# Brake light needs its own emissive copy of the exported material (driven per car).
			if _brake_mat == null:
				var dup: StandardMaterial3D = m.duplicate() as StandardMaterial3D
				if dup == null:
					continue
				dup.resource_name = m.resource_name
				dup.emission_enabled = true
				dup.emission = Color(1.0, 0.1, 0.05)
				dup.emission_energy_multiplier = BRAKE_ENERGY_IDLE
				_brake_mat = dup
			mi2.set_surface_override_material(s, _brake_mat)
	_from_glb = true
	return true
	return true


func _build_procedural(color: Color) -> void:
	var paint: StandardMaterial3D = StandardMaterial3D.new()
	paint.albedo_color = color
	paint.metallic = 0.4
	paint.roughness = 0.35
	var glass: StandardMaterial3D = StandardMaterial3D.new()
	glass.albedo_color = Color(0.15, 0.2, 0.25)
	glass.roughness = 0.1
	var rubber: StandardMaterial3D = StandardMaterial3D.new()
	rubber.albedo_color = Color(0.05, 0.05, 0.05)
	var head: StandardMaterial3D = StandardMaterial3D.new()
	head.albedo_color = Color(1.0, 0.95, 0.8)
	head.emission_enabled = true
	head.emission = Color(1.0, 0.95, 0.75)
	head.emission_energy_multiplier = 3.0
	var tail: StandardMaterial3D = StandardMaterial3D.new()
	tail.albedo_color = Color(0.8, 0.05, 0.05)
	tail.emission_enabled = true
	tail.emission = Color(1.0, 0.1, 0.05)
	tail.emission_energy_multiplier = BRAKE_ENERGY_IDLE
	_brake_mat = tail
	# Car faces local -Z (Godot forward).
	_add_box("Body", Vector3(1.9, 0.7, 4.4), Vector3(0, 0.75, 0), paint)
	_add_box("Cabin", Vector3(1.7, 0.6, 2.2), Vector3(0, 1.4, 0.3), glass)
	const WHEEL_NAMES: Array[String] = ["Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR"]
	for i: int in 4:
		# Pivot spins around its local X; the cylinder child is laid along X.
		var pivot: Node3D = Node3D.new()
		pivot.name = WHEEL_NAMES[i]
		pivot.position = Vector3(-0.95 if i % 2 == 0 else 0.95, WHEEL_RADIUS, -1.4 if i < 2 else 1.4)
		var w: MeshInstance3D = MeshInstance3D.new()
		var cm: CylinderMesh = CylinderMesh.new()
		cm.top_radius = WHEEL_RADIUS
		cm.bottom_radius = WHEEL_RADIUS
		cm.height = 0.3
		cm.radial_segments = 12
		w.mesh = cm
		w.material_override = rubber
		w.rotation = Vector3(0, 0, PI * 0.5)
		w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(w)
		add_child(pivot)
		_wheels.append(pivot)
	for sx: float in [-0.65, 0.65]:
		_add_box("Headlight", Vector3(0.4, 0.18, 0.05), Vector3(sx, 0.85, -2.21), head)
		_add_box("Taillight", Vector3(0.4, 0.15, 0.05), Vector3(sx, 0.85, 2.21), tail)


func _add_box(n: String, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = n
	var bm: BoxMesh = BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)

func assign_lane(idx: int, pts: PackedVector3Array, cum: PackedFloat32Array, total: float, at: float) -> void:
	lane_index = idx
	lane = pts
	lane_cum = cum
	lane_length = total
	distance = fposmod(at, maxf(total, 0.001))
	_apply_pose()


func sample(d: float) -> Vector3:
	var n: int = lane.size()
	if n == 0:
		return Vector3.ZERO
	var s: float = fposmod(d, maxf(lane_length, 0.001))
	# Linear scan is fine: lanes have few points.
	for i: int in n:
		var seg_end: float = lane_cum[i + 1] if i + 1 < lane_cum.size() else lane_length
		if s <= seg_end:
			var a: Vector3 = lane[i]
			var b: Vector3 = lane[(i + 1) % n]
			var seg: float = seg_end - lane_cum[i]
			return a.lerp(b, 0.0 if seg <= 0.0001 else (s - lane_cum[i]) / seg)
	return lane[0]


func forward_dir() -> Vector3:
	var f: Vector3 = sample(distance + 1.0) - sample(distance)
	f.y = 0.0
	return f.normalized() if f.length_squared() > 0.000001 else Vector3.FORWARD


## True if `p` lies in front of the car within STOP_DISTANCE and inside the lane width.
func is_blocking(p: Vector3) -> bool:
	var fwd: Vector3 = forward_dir()
	var d: Vector3 = p - global_position
	d.y = 0.0
	var ahead: float = d.dot(fwd)
	if ahead <= 0.0 or ahead >= STOP_DISTANCE:
		return false
	return (d - fwd * ahead).length() < LANE_HALF_WIDTH


func advance(delta: float, blocked: bool) -> void:
	stopped = blocked
	var target: float = 0.0 if blocked else cruise_speed
	var prev_speed: float = current_speed
	current_speed = move_toward(current_speed, target, (40.0 if blocked else 6.0) * delta)
	if _brake_mat != null:
		var braking: bool = blocked or current_speed < prev_speed
		_brake_mat.emission_energy_multiplier = BRAKE_ENERGY_BRAKING if braking else BRAKE_ENERGY_IDLE
	if current_speed <= 0.0:
		return
	distance = fposmod(distance + current_speed * delta, maxf(lane_length, 0.001))
	_apply_pose()
	# Forward is -Z, so rolling forward is a negative rotation around local X.
	for w: Node3D in _wheels:
		w.rotate_object_local(Vector3.RIGHT, -current_speed * delta / WHEEL_RADIUS)


func _apply_pose() -> void:
	if lane.size() < 2 or not is_inside_tree():
		return
	var p: Vector3 = sample(distance)
	var fwd: Vector3 = forward_dir()
	global_position = p
	global_basis = Basis.looking_at(fwd, Vector3.UP)
