extends PlayerState
## On the ground: run (sprint with swing held), jump, wall-run start, ground attacks.


func enter(_from: StringName, _msg: Dictionary) -> void:
	player.release_web()
	player.play_anim(&"idle")


func physics(delta: float) -> void:
	var t: TraversalTuning = player.tuning
	var wish: Vector3 = player.wish_dir()
	var sprint: bool = player.held(&"swing")
	var spd: float = t.sprint_speed if sprint else t.run_speed
	var target: Vector3 = wish * spd
	var hv: Vector3 = Vector3(player.velocity.x, 0.0, player.velocity.z)
	hv = hv.move_toward(target, t.ground_accel * delta)
	player.velocity.x = hv.x
	player.velocity.z = hv.z
	player.velocity.y = -1.0
	if wish.length() > 0.1:
		player.face_dir(wish, delta)
		player.play_anim(&"sprint" if sprint else &"run")
	else:
		player.play_anim(&"idle")
	if player.pressed(&"jump"):
		player.consume(&"jump")
		player.velocity.y = t.jump_velocity * (1.3 if sprint else 1.0)
		player.play_anim(&"jump", 0.05)
		player.change_state(&"airborne")
		return
	# Sprinting into a wall starts a vertical wall run.
	if sprint and hv.length() > t.wall_run_min_speed * 0.6:
		var hit: Dictionary = player.probe_wall(hv, 0.9)
		if not hit.is_empty():
			player.change_state(&"wall_run", {"normal": hit.normal})
			return


func post_move(_delta: float) -> void:
	if not player.is_on_floor():
		player.change_state(&"airborne")
