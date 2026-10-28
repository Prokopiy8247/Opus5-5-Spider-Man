class_name PlayerCombat
extends Node
## Hero melee: combo chain with auto-targeting (lunge to nearest enemy), dodge with Spider-Sense
## perfect window, finisher with full Focus, heal with Focus. Enemies implement take_hit(dmg, dir, kind).

const COMBO_WINDOW: float = 1.6
const LUNGE_RANGE: float = 9.0

var player: Player
var combo: int = 0
var combo_t: float = 0.0
var _sense_until: float = 0.0
var _perfect_until: float = 0.0


func _ready() -> void:
	player = get_parent() as Player
	Events.spider_sense.connect(_on_sense)


func _now() -> float:
	return float(Time.get_ticks_msec()) / 1000.0


func _on_sense(_attacker: Node3D, _perfect: bool) -> void:
	_sense_until = _now() + 0.6
	_perfect_until = _now() + GameState.mod(&"perfect_window", 0.15) + 0.25


## Called by Player every physics tick before the state runs.
func pre_state(delta: float) -> void:
	if combo > 0:
		combo_t -= delta
		if combo_t <= 0.0:
			combo = 0
			Events.combo_changed.emit(0)
	var s: StringName = player.state_id
	if s in [&"finisher", &"ko", &"hurt", &"zipping", &"mantle"]:
		return
	if player.pressed(&"dodge") and s != &"attack" and (s == &"grounded" or _sense_until > _now()):
		player.consume(&"dodge")
		do_dodge()
		return
	if player.pressed(&"heal") and GameState.focus >= 1.0 and GameState.hp < GameState.max_hp:
		player.consume(&"heal")
		GameState.add_focus(-1.0)
		GameState.set_hp(GameState.hp + GameState.mod(&"heal_amount", 35.0))
	if player.pressed(&"finisher") and GameState.focus >= GameState.mod(&"finisher_cost", 3.0) - 0.001:
		var tf: Node3D = nearest_enemy(4.0)
		if tf != null:
			player.consume(&"finisher")
			GameState.add_focus(-GameState.mod(&"finisher_cost", 3.0))
			Events.finisher_started.emit(tf, &"finisher_1")
			TimeScale.request_slowmo(0.4, 0.6)
			tf.call(&"take_hit", 999.0, -player.global_basis.z, &"finisher")
			player.change_state(&"finisher", {"duration": 1.0, "anim": &"finisher_1"})
			return
	if player.pressed(&"attack") and s in [&"grounded", &"airborne", &"attack", &"swinging"]:
		if s == &"attack" and player.state.time_in_state < 0.18:
			return
		player.consume(&"attack")
		_attack()


func nearest_enemy(r: float) -> Node3D:
	var best: Node3D = null
	var bd: float = r
	for n: Node in player.get_tree().get_nodes_in_group(&"enemy"):
		var e: Node3D = n as Node3D
		if e == null or not e.has_method(&"take_hit") or bool(e.get(&"dead")):
			continue
		var d: float = e.global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = e
	return best


func _attack() -> void:
	var tgt: Node3D = nearest_enemy(LUNGE_RANGE)
	var dir: Vector3 = -player.global_basis.z
	var speed: float = 0.0
	if tgt != null:
		var to: Vector3 = tgt.global_position - player.global_position
		to.y = 0.0
		dir = to.normalized()
		var d: float = to.length()
		speed = clampf((d - 1.2) / 0.18, 0.0, 40.0)
	combo += 1
	combo_t = GameState.mod(&"combo_window", COMBO_WINDOW)
	var idx: int = (combo - 1) % 5 + 1
	player.change_state(&"attack", {"duration": 0.26, "dir": dir, "speed": speed, "anim": StringName("combo_%d" % idx)})
	if tgt != null and tgt.global_position.distance_to(player.global_position) < 2.8 + speed * 0.18:
		var dmg: float = (10.0 + (8.0 if idx == 5 else 0.0)) * GameState.mod(&"damage")
		tgt.call(&"take_hit", dmg, dir, &"punch")
		TimeScale.hitstop(45 if idx < 5 else 90)
		GameState.add_focus(0.12 + (0.05 if combo >= 5 else 0.0))
		Events.hit_landed.emit(tgt, dmg, combo)
		GameState.add_xp(5, &"hit")
		_sfx(&"punch")
	else:
		_sfx(&"whoosh")
	Events.combo_changed.emit(combo)


func do_dodge() -> void:
	var wish: Vector3 = player.wish_dir()
	var dir: Vector3 = wish.normalized() if wish.length() > 0.1 else player.global_basis.z
	var perfect: bool = _perfect_until > _now()
	if perfect:
		Events.perfect_dodge.emit()
		TimeScale.request_slowmo(0.3, 0.4)
		GameState.add_focus(0.3)
	_sense_until = 0.0
	_perfect_until = 0.0
	player.change_state(&"dodge", {"duration": 0.3, "dir": dir, "speed": 13.0, "anim": &"dodge_l" if dir.dot(player.global_basis.x) < 0.0 else &"dodge_r"})
	_sfx(&"whoosh")


## Called by enemies. Returns true if the hit connected.
func receive_hit(dmg: float, from_dir: Vector3) -> bool:
	if player.state_id == &"dodge" or player.state_id == &"finisher" or player.state_id == &"ko":
		return false
	combo = 0
	Events.combo_changed.emit(0)
	GameState.damage(dmg, from_dir)
	if GameState.hp <= 0.0:
		player.change_state(&"ko", {"duration": 2.0})
	else:
		player.change_state(&"hurt", {"duration": 0.35, "dir": -from_dir, "speed": 5.0})
	return true


func _sfx(id: StringName) -> void:
	var sfx: Node = get_node_or_null(^"/root/Sfx")
	if sfx != null:
		sfx.call(&"play", id, player.global_position, 0.1)
