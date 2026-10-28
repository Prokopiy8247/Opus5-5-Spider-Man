class_name Enemy
extends CharacterBody3D
## Enemy AI: idle/patrol -> suspicious (?) -> alert (!) -> combat. Stats come from
## data/enemies/archetypes.json (ArchetypeDB). Attack tokens limit simultaneous attackers to 3.
## Telegraphs attacks via Events.spider_sense before striking. Ranged archetypes fire from range.
## Gadgets apply WEBBED/STUNNED via apply_status(). Alert propagates to the owning EnemyBase.

const MAX_ATTACKERS: int = 3
const MAX_BODIES: int = 16
const BODY_LIFETIME: float = 60.0
const BODY_MAX_DIST: float = 100.0
const FADE_TIME: float = 0.8
const HEAVY_KINDS: Array[StringName] = [&"launcher", &"finisher", &"heavy", &"gadget_explosion", &"fall"]
static var tokens: int = 0
static var bodies: Array = []  # downed Enemy nodes, oldest first

var _last_kind: StringName = &"punch"
var _last_dir: Vector3 = Vector3.ZERO
var _body_age: float = 0.0
var _fading: bool = false
var _air_top: float = -INF
const FALL_KILL_HEIGHT: float = 9.0

var archetype: StringName = &"thug"
var base_id: int = -1
var hp: float = 40.0
var dead: bool = false
var state: StringName = &"idle"
var awareness: float = 0.0
var status: StringName = &""
var cfg: Dictionary = {}
var _home: Vector3
var _attack_cd: float = 0.0
var _windup: float = -1.0
var _has_token: bool = false
var _stun: float = 0.0
var _icon: Label3D
var visual: Node3D


func _ready() -> void:
	add_to_group(&"enemy")
	collision_layer = 1 << 2
	collision_mask = 1 | (1 << 1) | (1 << 2) | (1 << 6)  # + layer 7 props
	var cs: CollisionShape3D = CollisionShape3D.new()
	var cap: CapsuleShape3D = CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	cfg = ArchetypeDB.get_config(archetype)
	hp = float(cfg.get("health", 40.0))
	var vs: Script = load("res://scripts/ui/enemy_visual.gd")
	visual = vs.new() as Node3D
	visual.name = "Visual"
	visual.set(&"archetype", archetype)
	add_child(visual)
	if archetype == &"brute":
		visual.scale = Vector3.ONE * 1.3
	_icon = Label3D.new()
	_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_icon.font_size = 96
	_icon.outline_size = 16
	_icon.position.y = 2.4
	_icon.no_depth_test = true
	add_child(_icon)
	_home = global_position
	_air_top = global_position.y
	_attack_cd = randf_range(0.5, 2.0)


func _exit_tree() -> void:
	_release_token()


func _ranged() -> bool:
	return bool(cfg.get("ranged", false))


func _range() -> float:
	return float(cfg.get("attack_range", 2.2))


func apply_status(s: StringName, seconds: float) -> void:
	if dead:
		return
	if s == &"COCOON":
		# Fully web-wrapped: counts as a defeat (kill method 'cocoon').
		kill(&"cocoon", Vector3.ZERO)
		return
	status = s
	_stun = maxf(_stun, seconds)
	_windup = -1.0
	_release_token()
	if state != &"alert":
		awareness = 1.0
		_set_state(&"alert")


func _set_state(s: StringName) -> void:
	if s == state:
		return
	state = s
	Events.enemy_state_changed.emit(self, s)
	if s == &"alert" and has_meta(&"enemy_base"):
		var my_base: Variant = get_meta(&"enemy_base")
		for b: Node in get_tree().get_nodes_in_group(&"enemy_base"):
			if b.get(&"base_id") == my_base and b.has_method(&"raise_alarm"):
				b.call(&"raise_alarm")


func _physics_process(delta: float) -> void:
	if dead:
		return
	var p: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = -1.0
	_stun = maxf(_stun - delta, 0.0)
	if _stun <= 0.0:
		status = &""
	if p == null:
		move_and_slide()
		return
	var to: Vector3 = p.global_position - global_position
	var dist: float = to.length()
	var flat: Vector3 = Vector3(to.x, 0.0, to.z)
	# Perception: vision cone 30 m, hearing 8 m, both scaled by the stealth skill.
	var sm: float = 1.0
	var sk: Node = get_node_or_null(^"/root/Skills")
	if sk != null:
		sm = float(sk.call(&"get_modifier", &"stealth_radius"))
	var fwd: Vector3 = -global_basis.z
	var sees: bool = dist < 30.0 * sm and (flat.normalized().dot(fwd) > 0.4 or dist < 8.0 * sm)
	if state in [&"idle", &"suspicious"]:
		awareness = clampf(awareness + (delta * (2.0 if dist < 12.0 * sm else 0.8) if sees else -delta * 0.3), 0.0, 1.0)
		if awareness > 0.25:
			_set_state(&"suspicious")
		if awareness >= 1.0:
			_set_state(&"alert")
		elif awareness <= 0.0 and state == &"suspicious":
			_set_state(&"idle")
	elif state == &"alert" and dist > 90.0:
		_release_token()
		_set_state(&"idle")
		awareness = 0.0
	if status == &"WEBBED":
		_icon.text = "#"
		_icon.modulate = Color(0.9, 0.9, 1.0)
	else:
		_icon.text = "?" if state == &"suspicious" else ("!" if state == &"alert" else "")
		_icon.modulate = Color(1, 0.85, 0.2) if state == &"suspicious" else Color(1, 0.2, 0.15)
	var hv: Vector3 = Vector3.ZERO
	var reach: float = _range()
	if _stun > 0.0:
		hv = Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, 30.0 * delta)
		visual.call(&"play", &"webbed" if status == &"WEBBED" else &"hurt", 0.05)
	elif state == &"alert":
		look_at(Vector3(p.global_position.x, global_position.y, p.global_position.z), Vector3.UP)
		_attack_cd -= delta
		var spd: float = float(cfg.get("speed", 5.5))
		if _windup >= 0.0:
			_windup -= delta
			if _windup < 0.0:
				_strike(p, dist)
		elif _ranged():
			# Keep distance: close in if too far, back off if the player is too close.
			if dist > reach * 0.8:
				hv = flat.normalized() * spd
			elif dist < 6.0:
				hv = -flat.normalized() * spd * 0.7
			visual.call(&"play", &"run" if hv.length() > 2.0 else &"idle", 0.2)
		elif dist > reach:
			var want: float = 2.0 if _has_token else 5.0
			if dist > want:
				hv = flat.normalized() * spd
			else:
				hv = flat.normalized().cross(Vector3.UP) * 2.0
			visual.call(&"play", &"run" if hv.length() > 3.0 else &"walk", 0.2)
		else:
			visual.call(&"play", &"idle", 0.2)
		if _attack_cd <= 0.0 and _windup < 0.0 and dist < reach + 0.8:
			if _ranged() or _has_token or tokens < MAX_ATTACKERS:
				if not _ranged() and not _has_token:
					_has_token = true
					tokens += 1
				_windup = float(cfg.get("windup_s", 0.55))
				Events.spider_sense.emit(self, true)
				visual.call(&"play", &"shoot" if _ranged() else (&"attack_heavy" if archetype == &"brute" else &"attack_light"), 0.05)
	else:
		visual.call(&"play", &"idle" if state == &"idle" else &"search", 0.3)
	velocity.x = hv.x
	velocity.z = hv.z
	move_and_slide()
	if global_position.y < -40.0:
		global_position = _home + Vector3.UP
		_air_top = global_position.y
	# Fall damage: a drop of FALL_KILL_HEIGHT or more (knocked off a roof) is a KO of kind 'fall'.
	if is_on_floor():
		if _air_top - global_position.y >= FALL_KILL_HEIGHT:
			kill(&"fall", Vector3(velocity.x, 0.0, velocity.z))
			return
		_air_top = global_position.y
	else:
		_air_top = maxf(_air_top, global_position.y)


func _strike(p: Node3D, dist: float) -> void:
	_attack_cd = randf_range(1.5, 2.8) * (1.5 if _ranged() else 1.0)
	_release_token()
	if dist < _range() + 1.0:
		var c: Node = p.get_node_or_null(^"Combat")
		if c != null:
			c.call(&"receive_hit", float(cfg.get("damage", 9.0)), (p.global_position - global_position).normalized())


func _release_token() -> void:
	if _has_token:
		_has_token = false
		tokens = maxi(tokens - 1, 0)


func take_hit(dmg: float, dir: Vector3, kind: StringName) -> void:
	if dead:
		return
	if kind == &"punch" and _stun <= 0.0 and ArchetypeDB.blocks_hit(self, global_position - dir * 2.0):
		visual.call(&"play", &"shield_block", 0.05)
		return
	if state != &"alert":
		awareness = 1.0
		_set_state(&"alert")
	_windup = -1.0
	_release_token()
	_attack_cd = maxf(_attack_cd, 0.8)
	hp -= dmg
	_stun = maxf(_stun, 0.4)
	_last_kind = kind
	_last_dir = dir
	if dir != Vector3.ZERO:
		velocity += Vector3(dir.x, 0.0, dir.z).normalized() * (3.0 if kind == &"punch" else 8.0)
	if hp <= 0.0:
		_die()


## Takedown / cocoon / scripted KO. dir = from attacker toward the enemy (picks back/front/side).
func knockout(kind: StringName = &"takedown", dir: Vector3 = Vector3.ZERO) -> void:
	kill(kind, dir)


## Fall damage / environment kill (roof fall): routes through the same KO path.
func kill(kind: StringName = &"fall", dir: Vector3 = Vector3.ZERO) -> void:
	if dead:
		return
	take_hit(hp + 1.0, dir, kind)


## Contract KO selection. hit_dir points from attacker toward the enemy.
## Heavy attack types -> heavy; attacker in front -> back; behind -> front; side -> side.
static func select_ko(kind: StringName, hit_dir: Vector3, enemy_forward: Vector3) -> StringName:
	if kind in HEAVY_KINDS:
		return &"heavy"
	var d: Vector3 = Vector3(hit_dir.x, 0.0, hit_dir.z)
	var f: Vector3 = Vector3(enemy_forward.x, 0.0, enemy_forward.z)
	if d.length_squared() < 0.0001 or f.length_squared() < 0.0001:
		return &"back"
	var dt: float = d.normalized().dot(f.normalized())
	if dt < -0.5:
		return &"back"   # pushed against its facing: hit from the front
	if dt > 0.5:
		return &"front"  # pushed along its facing: hit from behind
	return &"side"


func _die() -> void:
	dead = true
	_release_token()
	_icon.text = ""
	_icon.visible = false
	var ko: StringName = select_ko(_last_kind, _last_dir, -global_basis.z)
	set_meta(&"ko_kind", ko)
	if visual.has_method(&"play_ko"):
		visual.call(&"play_ko", ko)
	else:
		visual.call(&"play", &"ko", 0.05)
	collision_layer = 0
	collision_mask = 0
	velocity = Vector3.ZERO
	for c: Node in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).set_deferred(&"disabled", true)
	GameState.add_xp(int(cfg.get("xp", 25)), &"defeat")
	Events.enemy_state_changed.emit(self, &"ko")
	remove_from_group(&"enemy")
	add_to_group(&"enemy_body")
	set_meta(&"downed", true)
	_snap_to_floor()
	_register_body()


func _snap_to_floor() -> void:
	if not is_inside_tree():
		return
	var from: Vector3 = global_position + Vector3.UP * 1.0
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 80.0, 1)
	q.exclude = [get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position.y = (hit["position"] as Vector3).y


func _register_body() -> void:
	bodies = bodies.filter(func(b: Variant) -> bool: return is_instance_valid(b) and not (b as Enemy)._fading)
	bodies.append(self)
	while bodies.size() > MAX_BODIES:
		var old: Enemy = bodies.pop_front() as Enemy
		old._start_fade()
	_body_age = 0.0


func _process(delta: float) -> void:
	if not dead or _fading:
		return
	_body_age += delta
	if _body_age >= BODY_LIFETIME:
		_start_fade()
		return
	var p: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if p != null and p.global_position.distance_to(global_position) > BODY_MAX_DIST:
		_start_fade()


func _start_fade() -> void:
	if _fading:
		return
	_fading = true
	bodies.erase(self)
	var tw: Tween = create_tween()
	tw.tween_method(_set_fade, 0.0, 1.0, FADE_TIME)
	tw.tween_callback(queue_free)


func _set_fade(t: float) -> void:
	var stack: Array[Node] = [visual]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n == null:
			continue
		stack.append_array(n.get_children())
		if n is GeometryInstance3D:
			(n as GeometryInstance3D).transparency = t


func is_fading() -> bool:
	return _fading
