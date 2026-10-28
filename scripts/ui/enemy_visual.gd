class_name EnemyVisual
extends HumanoidVisual
## Thug visual: dark clothing, variant accent per archetype.

var archetype: StringName = &"thug"


func _ready() -> void:
	model_path = "res://assets/models/enemy.glb"
	body_color = Color(0.16, 0.16, 0.18)
	match archetype:
		&"armor": limb_color = Color(0.35, 0.37, 0.4)
		&"shield": limb_color = Color(0.2, 0.3, 0.2)
		&"brute": limb_color = Color(0.45, 0.2, 0.1)
		&"rifle": limb_color = Color(0.25, 0.22, 0.15)
		_: limb_color = Color(0.3, 0.3, 0.55)
	super._ready()


func _decorate_fallback(_head: Node3D, chest: Node3D) -> void:
	if archetype == &"shield":
		var mi: MeshInstance3D = MeshInstance3D.new()
		var bm: BoxMesh = BoxMesh.new()
		bm.size = Vector3(0.7, 1.0, 0.06)
		mi.mesh = bm
		mi.position = Vector3(0.0, 0.2, -0.4)
		mi.material_override = _mat(Color(0.5, 0.55, 0.6))
		chest.add_child(mi)
