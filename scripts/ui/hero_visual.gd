class_name HeroVisual
extends HumanoidVisual
## Hero visual: red torso/head, blue limbs, white spider emblem and white mask lenses.


func _ready() -> void:
	model_path = "res://assets/models/hero.glb"
	body_color = Color(0.78, 0.06, 0.08)
	limb_color = Color(0.08, 0.16, 0.55)
	super._ready()


## Recolours the hero: glb materials Suit_Primary/Suit_Secondary/Suit_Emblem, or the fallback meshes.
func apply_suit(primary: Color, secondary: Color, emblem: Color) -> void:
	body_color = primary
	limb_color = secondary
	_recolor(self, primary, secondary, emblem)


func _recolor(n: Node, primary: Color, secondary: Color, emblem: Color) -> void:
	if n is MeshInstance3D:
		var mi: MeshInstance3D = n as MeshInstance3D
		var ov: StandardMaterial3D = mi.material_override as StandardMaterial3D
		if ov != null:
			if ov.has_meta(&"role"):
				var role: StringName = ov.get_meta(&"role")
				ov.albedo_color = primary if role == &"primary" else (secondary if role == &"secondary" else emblem)
		elif mi.mesh != null:
			for i: int in mi.mesh.get_surface_count():
				var m: Material = mi.mesh.surface_get_material(i)
				if m == null:
					continue
				var c: Variant = null
				if m.resource_name.begins_with("Suit_Primary"):
					c = primary
				elif m.resource_name.begins_with("Suit_Secondary"):
					c = secondary
				elif m.resource_name.begins_with("Suit_Emblem"):
					c = emblem
				if c != null and m is BaseMaterial3D:
					var dup: BaseMaterial3D = (m as BaseMaterial3D).duplicate()
					dup.albedo_color = c
					mi.set_surface_override_material(i, dup)
	for ch: Node in n.get_children():
		_recolor(ch, primary, secondary, emblem)


func _mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = super._mat(c)
	if c == body_color:
		m.set_meta(&"role", &"primary")
	elif c == limb_color:
		m.set_meta(&"role", &"secondary")
	return m


func _decorate_fallback(head: Node3D, chest: Node3D) -> void:
	var white: StandardMaterial3D = _mat(Color(0.97, 0.97, 0.97))
	white.set_meta(&"role", &"emblem")
	white.emission_enabled = true
	white.emission = Color(0.6, 0.6, 0.6)
	for sx: float in [-1.0, 1.0]:
		var lens: MeshInstance3D = MeshInstance3D.new()
		var sm: SphereMesh = SphereMesh.new()
		sm.radius = 0.045
		sm.height = 0.03
		lens.mesh = sm
		lens.position = Vector3(0.045 * sx, 0.12, -0.105)
		lens.rotation = Vector3(PI * 0.5, 0.0, 0.3 * sx)
		lens.scale = Vector3(1.0, 1.0, 1.4)
		lens.material_override = white
		head.add_child(lens)
	# Emblem: body + 8 legs made of thin boxes on the chest front.
	var emb: Node3D = Node3D.new()
	emb.position = Vector3(0.0, 0.32, -0.165)
	chest.add_child(emb)
	var body: MeshInstance3D = MeshInstance3D.new()
	var bm: BoxMesh = BoxMesh.new()
	bm.size = Vector3(0.035, 0.11, 0.012)
	body.mesh = bm
	body.material_override = white
	emb.add_child(body)
	for i: int in 8:
		var leg: MeshInstance3D = MeshInstance3D.new()
		var lm: BoxMesh = BoxMesh.new()
		lm.size = Vector3(0.1, 0.01, 0.01)
		leg.mesh = lm
		leg.material_override = white
		var side: float = -1.0 if i < 4 else 1.0
		var k: int = i % 4
		leg.position = Vector3(side * 0.05, 0.035 - k * 0.025, 0.0)
		leg.rotation.z = side * (0.6 - k * 0.4)
		emb.add_child(leg)
