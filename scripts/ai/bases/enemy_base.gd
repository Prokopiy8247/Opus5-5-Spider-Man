class_name EnemyBase
extends Node3D
## Enemy base: guards patrol around it; if the player enters detect radius (scaled by
## Skills stealth_radius) with line of sight, the alarm is raised and 3 waves spawn.
## When the last wave is defeated: Events.base_cleared + XP reward.

@export var base_id: StringName = &"base_0"
@export var waves: int = 3
@export var detect_radius: float = 18.0
@export var patrol_radius: float = 10.0
@export var guards: int = 3
@export var wave_archetypes: Array[StringName] = [&"thug", &"gunner", &"brute"]
@export var wave_size: int = 3
@export var xp_reward: int = 300

var alarmed: bool = false
var wave: int = 0
var _cleared: bool = false
var _wave_enemies: Array[Node3D] = []
var _patrol: Array[Dictionary] = []  # {e: Node3D, a: float}


func _ready() -> void:
	add_to_group(&"enemy_base")
	_spawn_guards.call_deferred()


func _spawn_guards() -> void:
	for i: int in guards:
		var e: Node3D = _spawn(&"thug")
		if e != null:
			_patrol.append({&"e": e, &"a": TAU * float(i) / float(guards)})


func detect_radius_effective() -> float:
	var m: float = 1.0
	var sk: Node = get_node_or_null(^"/root/Skills")
	if sk != null:
		m = float(sk.call(&"get_modifier", &"stealth_radius"))
	return detect_radius * m


func _physics_process(delta: float) -> void:
	if _cleared:
		return
	if not alarmed:
		_update_patrol(delta)
		var p: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
		if p != null and _detects(p):
			raise_alarm()
		return
	_wave_enemies = _wave_enemies.filter(func(e: Node3D) -> bool:
		return is_instance_valid(e) and not bool(e.get(&"dead")))
	if _wave_enemies.is_empty():
		if wave < waves:
			_start_wave()
		else:
			_finish()


func _detects(p: Node3D) -> bool:
	var r: float = detect_radius_effective()
	var watchers: Array[Node3D] = [self]
	for d: Dictionary in _patrol:
		if is_instance_valid(d[&"e"]):
			watchers.append(d[&"e"] as Node3D)
	for w: Node3D in watchers:
		if w.global_position.distance_to(p.global_position) <= r:
			var from: Vector3 = w.global_position + Vector3.UP * 1.6
			var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, p.global_position + Vector3.UP, 1)
			if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				return true
	return false


func _update_patrol(delta: float) -> void:
	for d: Dictionary in _patrol:
		# Check validity on the raw Variant: casting a freed object with `as` is a script error.
		var raw: Variant = d[&"e"]
		if not is_instance_valid(raw):
			continue
		var e: Node3D = raw as Node3D
		if e == null or bool(e.get(&"dead")):
			continue
		d[&"a"] = float(d[&"a"]) + delta * 0.25
		var a: float = float(d[&"a"])
		var target: Vector3 = global_position + Vector3(cos(a), 0.0, sin(a)) * patrol_radius
		var flat: Vector3 = Vector3(target.x - e.global_position.x, 0.0, target.z - e.global_position.z)
		if e is CharacterBody3D and flat.length() > 0.3 and StringName(str(e.get(&"state"))) in [&"idle", &"PATROL"]:
			var cb: CharacterBody3D = e as CharacterBody3D
			cb.velocity.x = flat.normalized().x * 2.0
			cb.velocity.z = flat.normalized().z * 2.0


func raise_alarm() -> void:
	if alarmed or _cleared:
		return
	alarmed = true
	Events.base_alarm.emit(base_id)
	for d: Dictionary in _patrol:
		if is_instance_valid(d[&"e"]):
			_wave_enemies.append(d[&"e"] as Node3D)
	_patrol.clear()


func is_cleared() -> bool:
	return _cleared


func _start_wave() -> void:
	wave += 1
	Events.wave_started.emit(base_id, wave)
	var arch: StringName = wave_archetypes[(wave - 1) % wave_archetypes.size()]
	for i: int in wave_size + wave - 1:
		var e: Node3D = _spawn(arch)
		if e != null:
			e.set(&"state", &"alert")
			e.set(&"awareness", 1.0)
			_wave_enemies.append(e)


func _finish() -> void:
	_cleared = true
	Events.base_cleared.emit(base_id)
	GameState.add_xp(xp_reward, &"base")


func _spawn(arch: StringName) -> Node3D:
	var es: GDScript = load("res://scripts/ai/enemy.gd") as GDScript
	var e: Node3D = es.new() as Node3D
	e.set(&"archetype", arch)
	e.set_meta(&"enemy_base", base_id)
	var parent: Node = get_parent() if get_parent() != null else self
	parent.add_child(e)
	var a: float = randf() * TAU
	e.global_position = global_position + Vector3(cos(a), 0.5, sin(a)) * randf_range(3.0, 8.0)
	return e
