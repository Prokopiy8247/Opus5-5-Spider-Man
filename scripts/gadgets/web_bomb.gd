extends Gadget
## Webs every enemy within 5 m of the player (WEBBED for 4 s).

const RADIUS: float = 5.0
const DURATION: float = 4.0


func _init() -> void:
	id = &"web_bomb"
	display_name = "Web Bomb"
	cooldown_s = 10.0


func _fire(player: Node3D) -> bool:
	var hits: Array[Node3D] = enemies_near(player.global_position, RADIUS)
	if hits.is_empty():
		return false
	for e: Node3D in hits:
		Gadget.apply_status(e, &"WEBBED", DURATION)
	return true
