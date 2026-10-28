class_name Player
extends CharacterBody3D
## Hero controller. Owns a state machine of PlayerState objects (scripts/core/states/).
## Input comes from the keyboard/mouse or from set_bot_input() (QA bots).

const WORLD_MASK: int = 1
const ZIP_MASK: int = 1 << 7

const STATE_SCRIPTS: Dictionary = {
	&"grounded": preload("res://scripts/core/states/grounded_state.gd"),
	&"airborne": preload("res://scripts/core/states/airborne_state.gd"),
	&"free_fall": preload("res://scripts/core/states/airborne_state.gd"),
	&"swinging": preload("res://scripts/core/states/swing_state.gd"),
	&"zipping": preload("res://scripts/core/states/zip_state.gd"),
	&"point_launch": preload("res://scripts/core/states/launch_state.gd"),
	&"wall_run": preload("res://scripts/core/states/wall_run_state.gd"),
	&"mantle": preload("res://scripts/core/states/mantle_state.gd"),
	&"perched": preload("res://scripts/core/states/perched_state.gd"),
	&"dodge": preload("res://scripts/core/states/combat_state.gd"),
	&"attack": preload("res://scripts/core/states/combat_state.gd"),
	&"finisher": preload("res://scripts/core/states/combat_state.gd"),
	&"hurt": preload("res://scripts/core/states/combat_state.gd"),
	&"ko": preload("res://scripts/core/states/combat_state.gd"),
}

@export var tuning: TraversalTuning

var states: Dictionary = {}
var state: PlayerState
var state_id: StringName = &""
var visual: Node3D
var camera_rig: Node3D
var combat: Node  ## PlayerCombat, created in _ready.

# Input snapshot (refreshed every physics tick).
var move_input: Vector2 = Vector2.ZERO  ## x = strafe right, y = forward
var _held: Dictionary = {}
var _pressed: Dictionary = {}
var _released: Dictionary = {}
var _bot_active: bool = false
var _bot_move: Vector2 = Vector2.ZERO
var _bot_actions: Dictionary = {}
var _bot_prev: Dictionary = {}

# Shared traversal data.
var anchor: Vector3 = Vector3.INF
var next_hand: StringName = &"R"
var zip_target: Node3D
var highlighted_zip: Node3D
var last_safe_pos: Vector3 = Vector3.ZERO
var stuck_time: float = 0.0
var air_time: float = 0.0
var peak_fall_speed: float = 0.0
var trick_cooldown: float = 0.0
var _web_line: Node3D
var _zip_scan_t: float = 0.0

const INPUT_ACTIONS: Array[StringName] = [
	&"jump", &"swing", &"zip", &"dodge", &"attack", &"gadget_use", &"web_strike", &"throw",
	&"finisher", &"heal", &"scan", &"air_trick", &"gadget_next",
]


func _ready() -> void:
	add_to_group(&"player")
	collision_layer = 1 << 1
	collision_mask = WORLD_MASK | (1 << 4) | (1 << 8)
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.4
	if tuning == null:
		var t: Resource = load("res://data/traversal.tres") if ResourceLoader.exists("res://data/traversal.tres") else null
		tuning = t as TraversalTuning if t is TraversalTuning else TraversalTuning.new()
	visual = get_node_or_null(^"Visual") as Node3D
	camera_rig = get_node_or_null(^"CameraRig") as Node3D
	for sid: StringName in STATE_SCRIPTS:
		var scr: GDScript = STATE_SCRIPTS[sid]
		states[sid] = scr.new(self, sid)
	var combat_script: GDScript = load("res://scripts/combat/player_combat.gd")
	combat = combat_script.new()
	combat.name = &"Combat"
	add_child(combat)
	var gm_script: GDScript = load("res://scripts/gadgets/gadget_manager.gd")
	var gm: Node = gm_script.new()
	gm.name = &"GadgetManager"
	add_child(gm)
	if ResourceLoader.exists("res://scenes/vfx/web_line.tscn"):
		var ps: PackedScene = load("res://scenes/vfx/web_line.tscn")
		_web_line = ps.instantiate() as Node3D
		_web_line.visible = false
		add_child.call_deferred(_web_line)
	last_safe_pos = global_position
	change_state(&"airborne")


func _exit_tree() -> void:
	# States hold a strong ref back to the player; break the cycle so nothing leaks at exit.
	for s: PlayerState in states.values():
		s.player = null
	states.clear()
	state = null


# ---------------------------------------------------------------- public API

func get_state() -> StringName:
	return state_id


func get_velocity_world() -> Vector3:
	return velocity


func get_anchor() -> Vector3:
	return anchor


func teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	if camera_rig != null:
		camera_rig.reset_physics_interpolation()
	release_web(false)
	change_state(&"airborne")
	last_safe_pos = pos
	stuck_time = 0.0


func unstuck() -> void:
	var world: Node = get_tree().get_first_node_in_group(&"world")
	var p: Vector3 = last_safe_pos + Vector3.UP * 2.0
	if world != null and world.has_method(&"get_safe_rooftop"):
		p = world.call(&"get_safe_rooftop", global_position)
	teleport(p)


## move: x = strafe right, y = forward (camera relative). actions: input action name -> bool.
func set_bot_input(move: Vector2, actions: Dictionary) -> void:
	_bot_active = true
	_bot_move = move.limit_length(1.0)
	_bot_actions = actions.duplicate()


func release_bot() -> void:
	_bot_active = false


# ---------------------------------------------------------------- input

func held(a: StringName) -> bool:
	return bool(_held.get(a, false))


func pressed(a: StringName) -> bool:
	return bool(_pressed.get(a, false))


func released(a: StringName) -> bool:
	return bool(_released.get(a, false))


## Consume a press so a second state in the same tick doesn't react to it.
func consume(a: StringName) -> void:
	_pressed[a] = false


func _sample_input() -> void:
	_pressed.clear()
	_released.clear()
	if _bot_active:
		move_input = _bot_move
		for a: StringName in INPUT_ACTIONS:
			var now: bool = bool(_bot_actions.get(a, _bot_actions.get(String(a), false)))
			var was: bool = bool(_bot_prev.get(a, false))
			_held[a] = now
			_pressed[a] = now and not was
			_released[a] = was and not now
			_bot_prev[a] = now
		# One-shot actions are cleared after one tick, as documented for QA.
		for one: String in ["jump", "dodge", "zip", "web_strike", "finisher", "heal", "air_trick", "throw"]:
			_bot_actions.erase(one)
			_bot_actions.erase(StringName(one))
		return
	move_input = Vector2(
		Input.get_action_strength(&"move_right") - Input.get_action_strength(&"move_left"),
		Input.get_action_strength(&"move_forward") - Input.get_action_strength(&"move_back"))
	move_input = move_input.limit_length(1.0)
	for a: StringName in INPUT_ACTIONS:
		if not InputMap.has_action(a):
			continue
		_held[a] = Input.is_action_pressed(a)
		_pressed[a] = Input.is_action_just_pressed(a)
		_released[a] = Input.is_action_just_released(a)


## Camera yaw basis (flat). Falls back to the body basis.
func cam_basis() -> Basis:
	var yaw: float = rotation.y
	if camera_rig != null and camera_rig.has_method(&"get_yaw"):
		yaw = camera_rig.call(&"get_yaw")
	return Basis(Vector3.UP, yaw)


## World-space wish direction on the XZ plane.
func wish_dir() -> Vector3:
	var b: Basis = cam_basis()
	var d: Vector3 = b * Vector3(move_input.x, 0.0, -move_input.y)
	return d.limit_length(1.0)


func cam_forward() -> Vector3:
	if camera_rig != null and camera_rig.has_method(&"get_aim_forward"):
		return camera_rig.call(&"get_aim_forward")
	return -cam_basis().z


# ---------------------------------------------------------------- loop

func _physics_process(delta: float) -> void:
	_sample_input()
	trick_cooldown = maxf(trick_cooldown - delta, 0.0)
	_zip_scan_t -= delta
	if _zip_scan_t <= 0.0:
		_zip_scan_t = 0.1
		highlighted_zip = find_zip_point()
	if combat != null:
		combat.call(&"pre_state", delta)
	state.time_in_state += delta
	state.physics(delta)
	if velocity.length() > 120.0:
		velocity = velocity.limit_length(120.0)
	move_and_slide()
	state.post_move(delta)
	_anti_stuck(delta)
	_update_web_line()


func change_state(new_id: StringName, msg: Dictionary = {}) -> void:
	if not states.has(new_id):
		push_error("Player: unknown state %s" % new_id)
		return
	var old: StringName = state_id
	if state != null:
		state.exit(new_id)
	state = states[new_id]
	state_id = new_id
	state.time_in_state = 0.0
	state.enter(old, msg)
	if old != new_id:
		if OS.has_environment("WS_DEBUG"):
			print("DBG %s -> %s pos=%s v=%s a=%s" % [old, new_id, global_position.round(), velocity.round(), anchor.round()])
		Events.player_state_changed.emit(old, new_id)


func play_anim(anim: StringName, blend: float = 0.15) -> void:
	if visual != null and visual.has_method(&"play"):
		visual.call(&"play", anim, blend)


func set_lean(v: Vector3) -> void:
	if visual != null and visual.has_method(&"set_lean"):
		visual.call(&"set_lean", v)


func face_dir(dir: Vector3, delta: float, rate: float = 12.0) -> void:
	var flat: Vector3 = Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		return
	var target: float = atan2(-flat.x, -flat.z)
	rotation.y = lerp_angle(rotation.y, target, clampf(rate * delta, 0.0, 1.0))


func apply_gravity(delta: float, mult: float = 1.0) -> void:
	velocity.y -= tuning.gravity * mult * delta


func _anti_stuck(delta: float) -> void:
	var trying: bool = move_input.length() > 0.3 or held(&"swing")
	if trying and velocity.length() < 0.6 and state_id != &"perched" and state_id != &"attack":
		stuck_time += delta
	else:
		stuck_time = 0.0
	if stuck_time > 0.7:
		# Nudge up and back; most snags are on a ledge lip.
		global_position += Vector3.UP * 0.6 - wish_dir() * 0.3
		velocity = Vector3.UP * 4.0
		stuck_time = 0.35
		if state_id == &"grounded":
			change_state(&"airborne")
	if is_on_floor() and state_id == &"grounded":
		last_safe_pos = global_position
	if global_position.y < -40.0:
		unstuck()


# ---------------------------------------------------------------- web helpers

func hand_position(hand: StringName) -> Vector3:
	if visual != null:
		var n: Node3D = visual.find_child("Hand" + String(hand), true, false) as Node3D
		if n != null:
			return n.global_position
	var side: float = -0.35 if hand == &"L" else 0.35
	return global_transform * Vector3(side, 1.5, 0.0)


func attach_web(point: Vector3) -> StringName:
	anchor = point
	var hand: StringName = next_hand
	next_hand = &"L" if next_hand == &"R" else &"R"
	if visual != null and visual.has_method(&"set_reach_target"):
		visual.call(&"set_reach_target", hand, point)
	Events.web_attached.emit(point, hand)
	_sfx(&"thwip")
	return hand


func release_web(emit: bool = true) -> void:
	if anchor == Vector3.INF:
		return
	anchor = Vector3.INF
	if _web_line != null and _web_line.has_method(&"fade_out"):
		_web_line.call(&"fade_out")
	if emit:
		Events.web_released.emit()


func _update_web_line() -> void:
	if _web_line == null or not _web_line.is_inside_tree():
		return
	var showing: bool = anchor != Vector3.INF
	if showing:
		_web_line.visible = true
		var hand: StringName = &"L" if next_hand == &"R" else &"R"
		if _web_line.has_method(&"set_points"):
			var tension: float = clampf(velocity.length() / tuning.swing_max_speed, 0.0, 1.0)
			_web_line.call(&"set_points", hand_position(hand), anchor, tension)


func _sfx(id: StringName) -> void:
	var sfx: Node = get_node_or_null(^"/root/Sfx")
	if sfx != null and sfx.has_method(&"play"):
		sfx.call(&"play", id, global_position, 0.1)


func ray(from: Vector3, to: Vector3, mask: int = WORLD_MASK) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask, [get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(q)


## Picks a swing anchor with a cone of rays forward/up around velocity+camera.
## Score = height near ideal + distance near ideal + alignment with travel + bonus for edges.
func find_anchor() -> Vector3:
	var t: TraversalTuning = tuning
	var origin: Vector3 = global_position + Vector3.UP * 1.2
	var vel_flat: Vector3 = Vector3(velocity.x, 0.0, velocity.z)
	var fwd: Vector3 = cam_forward()
	fwd.y = 0.0
	if vel_flat.length() > 4.0:
		fwd = (fwd.normalized() * 0.4 + vel_flat.normalized() * 0.6)
	if fwd.length_squared() < 0.001:
		fwd = -global_basis.z
	fwd = fwd.normalized()
	var wish: Vector3 = wish_dir()
	if wish.length() > 0.2:
		fwd = (fwd + wish * 0.5).normalized()
	var right: Vector3 = fwd.cross(Vector3.UP).normalized()
	var best: Vector3 = Vector3.INF
	var best_score: float = -INF
	var ny: int = maxi(t.swing_ray_count_yaw, 1)
	var np: int = maxi(t.swing_ray_count_pitch, 1)
	for iy: int in ny:
		var fy: float = 0.0 if ny == 1 else float(iy) / float(ny - 1) * 2.0 - 1.0
		var yaw: float = deg_to_rad(t.swing_cone_yaw_deg) * fy
		var hdir: Vector3 = fwd.rotated(Vector3.UP, yaw)
		for ip: int in np:
			var fp: float = 0.5 if np == 1 else float(ip) / float(np - 1)
			var pitch: float = deg_to_rad(lerpf(t.swing_pitch_min_deg, t.swing_pitch_max_deg, fp))
			var dir: Vector3 = (hdir * cos(pitch) + Vector3.UP * sin(pitch)).normalized()
			var hit: Dictionary = ray(origin, origin + dir * t.swing_ray_length)
			if hit.is_empty():
				continue
			var p: Vector3 = hit.position
			var h: float = p.y - global_position.y
			if h < 6.0:
				continue
			var d: float = origin.distance_to(p)
			if d < t.swing_min_rope or d > t.swing_max_rope:
				continue
			var score: float = 0.0
			score -= absf(h - t.swing_ideal_height) / t.swing_ideal_height * 1.5
			score -= absf(d - t.swing_ideal_distance) / t.swing_ideal_distance
			var flat_to: Vector3 = Vector3(p.x - origin.x, 0.0, p.z - origin.z).normalized()
			score += flat_to.dot(fwd) * 2.0
			# Prefer points that are off to the side of travel (avoid swinging straight into a wall).
			score += minf(absf(flat_to.dot(right)), 0.5) * 0.6
			var n: Vector3 = hit.normal
			# Edges: a ray slightly above the hit going inward finds empty space -> corner/roof edge.
			if absf(n.y) < 0.3:
				var above: Dictionary = ray(p + n * 0.3 + Vector3.UP * 2.5, p - n * 1.5 + Vector3.UP * 2.5)
				if above.is_empty():
					score += 0.8
			elif n.y < -0.5:
				score += 0.4  ## underside of bridge/crane
			# Anchors must be ahead of the hero, otherwise the arc kills momentum.
			if flat_to.dot(fwd) < 0.25:
				continue
			if score > best_score:
				best_score = score
				best = p
	if best == Vector3.INF:
		best = _side_anchor(origin, fwd, right)
	return best


## Fallback: look sideways/forward-diagonal for a wall across the street and anchor on it
## about ideal height above the hero (or just under its roof). Keeps chains alive low in a street.
func _side_anchor(origin: Vector3, fwd: Vector3, right: Vector3) -> Vector3:
	var t: TraversalTuning = tuning
	var best: Vector3 = Vector3.INF
	var best_d: float = INF
	for side: float in [-1.0, 1.0]:
		for k: float in [0.0, 0.6, 1.0, 1.6]:
			var dir: Vector3 = (right * side + fwd * k).normalized()
			var hit: Dictionary = ray(origin, origin + dir * 70.0)
			if hit.is_empty() or absf((hit.normal as Vector3).y) > 0.3:
				continue
			var wall_p: Vector3 = hit.position
			var nrm: Vector3 = hit.normal
			var flat_d: float = Vector2(wall_p.x - origin.x, wall_p.z - origin.z).length()
			if flat_d < 1.5:
				continue
			var top_hit: Dictionary = ray(wall_p - nrm * 0.5 + Vector3.UP * 400.0, wall_p - nrm * 0.5)
			var roof_y: float = (top_hit.position as Vector3).y if not top_hit.is_empty() else wall_p.y
			var y: float = minf(global_position.y + t.swing_ideal_height * 0.8, roof_y - 0.5)
			if y - global_position.y < 6.0:
				continue
			if flat_d < best_d:
				best_d = flat_d
				best = Vector3(wall_p.x, y, wall_p.z) + nrm * 0.05
	return best


## Highlighted zip point: nearest Area3D in group zip_point inside the camera cone.
func find_zip_point() -> Node3D:
	var origin: Vector3 = global_position + Vector3.UP
	var fwd: Vector3 = cam_forward().normalized()
	var best: Node3D = null
	var best_score: float = -INF
	var cos_cone: float = cos(deg_to_rad(tuning.zip_cone_deg))
	for n: Node in get_tree().get_nodes_in_group(&"zip_point"):
		var z: Node3D = n as Node3D
		if z == null or not z.is_inside_tree():
			continue
		var to: Vector3 = z.global_position - origin
		var d: float = to.length()
		if d < 3.0 or d > tuning.zip_range:
			continue
		var c: float = to.normalized().dot(fwd)
		if c < cos_cone:
			continue
		var hit: Dictionary = ray(origin, z.global_position - to.normalized() * 0.8)
		if not hit.is_empty():
			continue
		var score: float = c * 2.0 - d / tuning.zip_range
		if score > best_score:
			best_score = score
			best = z
	return best


## Generic air-state transitions shared by airborne/launch/etc. Returns true if state changed.
func try_air_actions() -> bool:
	if pressed(&"zip") and highlighted_zip != null:
		consume(&"zip")
		change_state(&"zipping", {"target": highlighted_zip})
		return true
	if held(&"swing") and (pressed(&"swing") or states[state_id].time_in_state > 0.12):
		var a: Vector3 = find_anchor()
		if a != Vector3.INF:
			change_state(&"swinging", {"anchor": a})
			return true
	if pressed(&"air_trick") and trick_cooldown <= 0.0:
		do_air_trick()
	return false


func do_air_trick() -> void:
	trick_cooldown = 0.7
	play_anim(&"air_trick_1" if randf() < 0.5 else &"air_trick_2", 0.1)
	GameState.add_focus(0.08)


## Wall probe in a direction; returns hit dictionary or empty.
func probe_wall(dir: Vector3, dist: float = 1.2, height: float = 1.0) -> Dictionary:
	var o: Vector3 = global_position + Vector3.UP * height
	var hit: Dictionary = ray(o, o + dir.normalized() * dist)
	if hit.is_empty():
		return hit
	var n: Vector3 = hit.normal
	if absf(n.y) > 0.35:
		return {}
	return hit


## Ledge check in front: returns top point for mantle/vault or Vector3.INF.
func find_ledge(dir: Vector3, max_h: float = 2.6) -> Vector3:
	var flat: Vector3 = Vector3(dir.x, 0.0, dir.z).normalized()
	if flat.length_squared() < 0.01:
		return Vector3.INF
	if probe_wall(flat, 1.0, 0.6).is_empty():
		return Vector3.INF
	var top_o: Vector3 = global_position + flat * 0.9 + Vector3.UP * (max_h + 0.4)
	var down: Dictionary = ray(top_o, top_o + Vector3.DOWN * (max_h + 0.3))
	if down.is_empty() or (down.normal as Vector3).y < 0.7:
		return Vector3.INF
	var p: Vector3 = down.position
	if p.y - global_position.y < 0.5:
		return Vector3.INF
	# Head room.
	if not ray(p + Vector3.UP * 0.2, p + Vector3.UP * 1.8).is_empty():
		return Vector3.INF
	return p
