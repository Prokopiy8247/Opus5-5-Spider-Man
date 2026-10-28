class_name CameraRig
extends Node3D
## Third-person orbit camera: mouse look, spring-arm collision, speed-based distance/FOV,
## shake from Events. top_level so it smooths independently of the body rotation.

@export var distance: float = 4.6
@export var height: float = 1.7
@export var sensitivity: float = 0.0025

var yaw: float = 0.0
var pitch: float = -0.2
var _shake: float = 0.0
var _target: Node3D
var _cam: Camera3D
var _arm: SpringArm3D
var _fov: float = 70.0
var _manual_t: float = 10.0


func _ready() -> void:
	_target = get_parent() as Node3D
	top_level = true
	# The rig follows the interpolated body in _process itself, so it must not be physics-interpolated.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_arm = SpringArm3D.new()
	_arm.name = "Arm"
	_arm.collision_mask = 1
	_arm.margin = 0.3
	_arm.spring_length = distance
	add_child(_arm)
	var sh: SphereShape3D = SphereShape3D.new()
	sh.radius = 0.25
	_arm.shape = sh
	_cam = Camera3D.new()
	_cam.name = "Camera3D"
	_cam.fov = 70.0
	_cam.far = 2500.0
	_cam.near = 0.1
	_arm.add_child(_cam)
	_cam.make_current()
	if _target != null:
		yaw = _target.rotation.y
		_arm.add_excluded_object((_target as CollisionObject3D).get_rid())
	Events.landed.connect(func(s: float, hero: bool) -> void: add_shake(0.35 if hero else clampf(s / 60.0, 0.0, 0.2)))
	Events.hit_landed.connect(func(_t: Node3D, _d: float, _c: int) -> void: add_shake(0.08))
	Events.player_damaged.connect(func(_a: float, _f: Vector3) -> void: add_shake(0.2))
	if not _is_bot():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _is_bot() -> bool:
	var qa: Node = get_node_or_null(^"/root/QA")
	return qa != null and bool(qa.get(&"active"))


func get_yaw() -> float:
	return yaw


func get_aim_forward() -> Vector3:
	return -global_basis.z if is_inside_tree() else Vector3.FORWARD


func get_camera() -> Camera3D:
	return _cam


func add_shake(a: float) -> void:
	_shake = maxf(_shake, a)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m: InputEventMouseMotion = e
		yaw -= m.relative.x * sensitivity
		pitch = clampf(pitch - m.relative.y * sensitivity, -1.3, 0.9)
		_manual_t = 0.0
	elif e is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and not get_tree().paused:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	if _target == null:
		return
	_manual_t += delta
	var vel: Vector3 = _target.get(&"velocity") if _target is CharacterBody3D else Vector3.ZERO
	var hv: Vector3 = Vector3(vel.x, 0.0, vel.z)
	var spd: float = vel.length()
	# Auto-follow travel direction when the mouse is idle and moving fast (bot always).
	# Bots keep a fixed heading so "forward" stays along the avenue.
	if hv.length() > 6.0 and _manual_t > 1.2 and not _is_bot():
		var want: float = atan2(-hv.x, -hv.z)
		yaw = lerp_angle(yaw, want, clampf(delta * 1.8, 0.0, 1.0))
		pitch = lerpf(pitch, -0.18, delta * 0.8)
	var k: float = clampf(spd / 45.0, 0.0, 1.0)
	_arm.spring_length = lerpf(_arm.spring_length, distance + k * 2.6, clampf(delta * 3.0, 0.0, 1.0))
	_fov = lerpf(_fov, 70.0 + 25.0 * k, clampf(delta * 3.0, 0.0, 1.0))
	_cam.fov = _fov
	var pos: Vector3 = _target.get_global_transform_interpolated().origin + Vector3.UP * height
	global_position = global_position.lerp(pos, clampf(delta * 18.0, 0.0, 1.0)) if global_position.distance_to(pos) < 8.0 else pos
	rotation = Vector3(pitch, yaw, 0.0)
	_arm.position = Vector3(0.45, 0.0, 0.0)
	_shake = move_toward(_shake, 0.0, delta * 1.5)
	if _shake > 0.0:
		_cam.h_offset = randf_range(-1.0, 1.0) * _shake * 0.3
		_cam.v_offset = randf_range(-1.0, 1.0) * _shake * 0.3
	else:
		_cam.h_offset = 0.0
		_cam.v_offset = 0.0
