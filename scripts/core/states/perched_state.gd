extends PlayerState
## Perched on a zip/perch point: holds still; jump or move leaves, zip chains to the next point.


func enter(_from: StringName, _msg: Dictionary) -> void:
	player.velocity = Vector3.ZERO
	player.play_anim(&"perch", 0.1)


func physics(_delta: float) -> void:
	player.velocity = Vector3.ZERO
	if player.pressed(&"jump"):
		player.consume(&"jump")
		player.velocity = Vector3.UP * player.tuning.jump_velocity + player.cam_forward() * 6.0
		player.change_state(&"airborne")
		return
	if player.pressed(&"zip") and player.highlighted_zip != null:
		player.consume(&"zip")
		player.change_state(&"zipping", {"target": player.highlighted_zip})
		return
	if player.held(&"swing") and time_in_state > 0.2:
		player.velocity = player.cam_forward() * 8.0 + Vector3.UP * 4.0
		player.change_state(&"airborne")
		return
	if player.wish_dir().length() > 0.5 and time_in_state > 0.3:
		player.change_state(&"airborne")
