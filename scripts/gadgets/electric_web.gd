extends Gadget
## Stuns the nearest enemy within 15 m, then chains to up to 3 enemies total (6 m per hop).

const RANGE: float = 15.0
const HOP: float = 6.0
const MAX_TARGETS: int = 3
const DURATION: float = 3.0


func _init() -> void:
	id = &"electric_web"
	display_name = "Electric Web"
	cooldown_s = 9.0


func _fire(player: Node3D) -> bool:
	var first: Array[Node3D] = enemies_near(player.global_position, RANGE)
	if first.is_empty():
		return false
	var chain: Array[Node3D] = [first[0]]
	while chain.size() < MAX_TARGETS:
		var nxt: Node3D = null
		for e: Node3D in enemies_near(chain[-1].global_position, HOP):
			if not chain.has(e):
				nxt = e
				break
		if nxt == null:
			break
		chain.append(nxt)
	for e: Node3D in chain:
		Gadget.apply_status(e, &"STUNNED", DURATION)
		if e.has_method(&"take_hit"):
			e.call(&"take_hit", 5.0, Vector3.ZERO, &"gadget")
	return true
