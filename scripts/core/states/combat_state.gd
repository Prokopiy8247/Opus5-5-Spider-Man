extends PlayerState
## Shared combat state for dodge / attack / finisher / hurt / ko. Timed actions driven by PlayerCombat.

var dur: float = 0.3
var dir: Vector3 = Vector3.ZERO
var speed: float = 0.0


func enter(_from: StringName, msg: Dictionary) -> void:
	dur = float(msg.get("duration", 0.3))
	dir = msg.get("dir", Vector3.ZERO)
	speed = float(msg.get("speed", 0.0))
	player.play_anim(msg.get("anim", id), 0.05)


func physics(delta: float) -> void:
	var v: Vector3 = dir * speed
	if id == &"finisher" or id == &"ko":
		v = Vector3.ZERO
	player.velocity.x = v.x
	player.velocity.z = v.z
	if player.is_on_floor():
		player.velocity.y = -1.0
	else:
		player.apply_gravity(delta, 0.4 if id == &"attack" else 1.0)
	if dir.length() > 0.1:
		player.face_dir(dir, delta, 20.0)
	# Dodge cancels an attack (Ctrl), as in the original.
	if id == &"attack" and player.pressed(&"dodge"):
		player.consume(&"dodge")
		player.combat.call(&"do_dodge")
		return
	if time_in_state >= dur:
		if id == &"ko":
			GameState.set_hp(GameState.max_hp)
			player.unstuck()
			return
		if id == &"finisher":
			Events.finisher_ended.emit()
		player.change_state(&"grounded" if player.is_on_floor() else &"airborne")
