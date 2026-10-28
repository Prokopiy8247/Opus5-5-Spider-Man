extends PlayerState
## Wall run: up the wall when moving into it, sideways when moving along it.
## Jump kicks off; reaching the top mantles onto the roof; releasing swing drops off.

var normal: Vector3 = Vector3.BACK


func enter(_from: StringName, msg: Dictionary) -> void:
	normal = msg.get("normal", -player.global_basis.z)
	normal.y = 0.0
	normal = normal.normalized()
	player.release_web()
	player.play_anim(&"wall_run_up", 0.1)


func physics(delta: float) -> void:
	var t: TraversalTuning = player.tuning
	var wish: Vector3 = player.wish_dir()
	var along: Vector3 = normal.cross(Vector3.UP)
	var side_amt: float = wish.dot(along)
	var vel: Vector3 = -normal * 2.0
	if absf(side_amt) > 0.6:
		vel += along * signf(side_amt) * t.wall_run_speed
		player.play_anim(&"wall_run_r" if side_amt > 0.0 else &"wall_run_l", 0.15)
	else:
		vel += Vector3.UP * t.wall_run_up_speed
		player.play_anim(&"wall_run_up", 0.15)
	player.velocity = vel
	player.face_dir(-normal, delta, 10.0)
	if player.pressed(&"jump"):
		player.consume(&"jump")
		player.velocity = normal * t.wall_kick_speed + Vector3.UP * t.jump_velocity
		player.change_state(&"airborne")
		return
	if player.try_air_actions():
		return
	# Wall top reached -> mantle.
	if player.probe_wall(-normal, 1.4, 0.4).is_empty():
		var top: Vector3 = player.find_ledge(-normal, 3.0)
		if top != Vector3.INF:
			player.change_state(&"mantle", {"top": top})
		else:
			player.velocity = Vector3.UP * 6.0 - normal * 4.0
			player.change_state(&"airborne")
		return
	if time_in_state > 0.25 and not player.held(&"swing") and wish.length() < 0.1:
		player.velocity = normal * 3.0
		player.change_state(&"airborne")
