class_name Gadget
extends Node
## Base gadget. Subclasses override _fire(player) -> bool. activate() handles cooldown,
## Skills gadget_cooldown modifier and Events.gadget_used.

var id: StringName = &""
var display_name: String = ""
var cooldown_s: float = 8.0
var cooldown_left: float = 0.0


func _process(delta: float) -> void:
	cooldown_left = maxf(cooldown_left - delta, 0.0)


func effective_cooldown() -> float:
	var m: float = 1.0
	var sk: Node = get_node_or_null(^"/root/Skills")
	if sk != null:
		m = float(sk.call(&"get_modifier", &"gadget_cooldown"))
	return cooldown_s * m


func activate(player: Node3D) -> bool:
	if cooldown_left > 0.0 or player == null:
		return false
	if not _fire(player):
		return false
	cooldown_left = effective_cooldown()
	Events.gadget_used.emit(id)
	return true


func _fire(_player: Node3D) -> bool:
	return false


## Enemies alive within radius of a point, nearest first.
func enemies_near(pos: Vector3, radius: float) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for n: Node in get_tree().get_nodes_in_group(&"enemy"):
		var e: Node3D = n as Node3D
		if e == null or bool(e.get(&"dead")):
			continue
		if e.global_position.distance_to(pos) <= radius:
			out.append(e)
	out.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_squared_to(pos) < b.global_position.distance_squared_to(pos))
	return out


## Applies an AI status (WEBBED/STUNNED). Uses enemy.apply_status(state, seconds) when the
## lead adds it; otherwise falls back to the existing Enemy._stun timer.
static func apply_status(e: Node3D, status: StringName, seconds: float) -> void:
	if e.has_method(&"apply_status"):
		e.call(&"apply_status", status, seconds)
	else:
		e.set(&"_stun", maxf(float(e.get(&"_stun")), seconds))
