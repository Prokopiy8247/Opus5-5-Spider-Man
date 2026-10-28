extends Gadget
## Pins the nearest enemy within 20 m to a wall (if one is within 3 m behind it) or the ground.

const RANGE: float = 20.0
const DURATION: float = 5.0


func _init() -> void:
	id = &"impact_web"
	display_name = "Impact Web"
	cooldown_s = 6.0


func _fire(player: Node3D) -> bool:
	var hits: Array[Node3D] = enemies_near(player.global_position, RANGE)
	if hits.is_empty():
		return false
	var e: Node3D = hits[0]
	var dir: Vector3 = e.global_position - player.global_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
	var from: Vector3 = e.global_position + Vector3.UP
	var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, from + dir * 3.0, 1)
	var hit: Dictionary = e.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		var p: Vector3 = hit[&"position"] - dir * 0.45
		e.global_position = Vector3(p.x, e.global_position.y, p.z)
	if e is CharacterBody3D:
		(e as CharacterBody3D).velocity = Vector3.ZERO
	Gadget.apply_status(e, &"WEBBED", DURATION)
	return true
