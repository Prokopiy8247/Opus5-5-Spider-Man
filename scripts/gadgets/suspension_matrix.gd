extends Gadget
## Lifts enemies within 6 m 2.5 m into the air for 3 s, then drops them.

const RADIUS: float = 6.0
const DURATION: float = 3.0
const LIFT: float = 2.5

var _held: Array[Dictionary] = []  # {e: Node3D, y: float, t: float}


func _init() -> void:
	id = &"suspension_matrix"
	display_name = "Suspension Matrix"
	cooldown_s = 12.0


func _fire(player: Node3D) -> bool:
	var hits: Array[Node3D] = enemies_near(player.global_position, RADIUS)
	if hits.is_empty():
		return false
	for e: Node3D in hits:
		_held.append({&"e": e, &"y": e.global_position.y + LIFT, &"t": DURATION})
		Gadget.apply_status(e, &"STUNNED", DURATION)
	return true


func _physics_process(delta: float) -> void:
	for i: int in range(_held.size() - 1, -1, -1):
		var h: Dictionary = _held[i]
		var e: Node3D = h[&"e"] as Node3D
		h[&"t"] = float(h[&"t"]) - delta
		if not is_instance_valid(e) or float(h[&"t"]) <= 0.0:
			_held.remove_at(i)
			continue
		e.global_position.y = lerpf(e.global_position.y, float(h[&"y"]), minf(delta * 6.0, 1.0))
		if e is CharacterBody3D:
			(e as CharacterBody3D).velocity = Vector3.ZERO
