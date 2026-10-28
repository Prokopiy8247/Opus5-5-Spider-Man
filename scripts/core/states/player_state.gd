class_name PlayerState
extends RefCounted
## Base class for the hero state machine. Each state is a RefCounted owned by Player.

var player: Player
var id: StringName = &""
var time_in_state: float = 0.0


func _init(p: Player, state_id: StringName) -> void:
	player = p
	id = state_id


func enter(_from: StringName, _msg: Dictionary) -> void:
	pass


func exit(_to: StringName) -> void:
	pass


## Called every physics tick. Must leave player.velocity set; Player calls move_and_slide().
func physics(_delta: float) -> void:
	pass


## Optional hook after move_and_slide().
func post_move(_delta: float) -> void:
	pass
