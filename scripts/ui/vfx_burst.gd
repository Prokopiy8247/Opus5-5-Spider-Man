class_name VfxBurst
extends Node3D
## Generic one-shot VFX root: builds GPUParticles3D / a scaling mesh from exported settings,
## play() emits, and the node frees itself when done. Used by hit_spark, land_dust, shockwave, cocoon, explosion.

@export_enum("spark", "dust", "shockwave", "cocoon", "explosion") var kind: String = "spark"
@export var lifetime: float = 0.6
@export var autoplay: bool = false

var _played: bool = false


func _ready() -> void:
	if autoplay:
		play()


func play() -> void:
	if _played:
		return
	_played = true
	match kind:
		"spark":
			_particles(24, Color(1.0, 0.9, 0.5), 0.05, 9.0, 0.25, 0.0, true)
		"dust":
			_particles(28, Color(0.6, 0.56, 0.5, 0.6), 0.35, 3.0, 0.9, -0.5, false)
		"shockwave":
			_ring(Color(0.8, 0.9, 1.0, 0.7), 6.0)
		"cocoon":
			_cocoon()
		"explosion":
			_particles(60, Color(1.0, 0.5, 0.15), 0.4, 8.0, 0.8, 2.0, true)
			_particles(30, Color(0.2, 0.2, 0.2, 0.7), 0.8, 3.0, 1.6, 1.5, false)
			_flash(Color(1.0, 0.6, 0.3), 12.0)
	var t: SceneTreeTimer = get_tree().create_timer(lifetime + 0.2)
	t.timeout.connect(queue_free)


func _particles(amount: int, col: Color, size: float, speed: float, life: float, gravity_y: float, emissive: bool) -> void:
	var p: GPUParticles3D = GPUParticles3D.new()
	p.amount = amount
	p.one_shot = true
	p.explosiveness = 0.95
	p.lifetime = life
	var pm: ParticleProcessMaterial = ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 180.0 if kind != "dust" else 80.0
	pm.initial_velocity_min = speed * 0.5
	pm.initial_velocity_max = speed
	pm.gravity = Vector3(0.0, gravity_y if gravity_y != 0.0 else -9.8, 0.0)
	pm.damping_min = 2.0
	pm.damping_max = 4.0
	pm.scale_min = 0.6
	pm.scale_max = 1.2
	var curve: Curve = Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	var ct: CurveTexture = CurveTexture.new()
	ct.curve = curve
	pm.scale_curve = ct
	p.process_material = pm
	var q: QuadMesh = QuadMesh.new()
	q.size = Vector2(size, size)
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	m.vertex_color_use_as_albedo = true
	if emissive:
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 3.0
	q.material = m
	p.draw_pass_1 = q
	add_child(p)
	p.emitting = true


func _ring(col: Color, radius: float) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var tm: TorusMesh = TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	mi.mesh = tm
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = col
	mi.material_override = m
	mi.scale = Vector3.ONE * 0.2
	add_child(mi)
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 0.3, radius), lifetime).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(m, "albedo_color:a", 0.0, lifetime)


func _cocoon() -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = 0.45
	cm.height = 1.9
	mi.mesh = cm
	mi.position.y = 0.95
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = Color(0.92, 0.93, 0.96, 0.85)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.4
	mi.material_override = m
	mi.scale = Vector3(0.2, 0.2, 0.2)
	add_child(mi)
	var tw: Tween = create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(lifetime - 0.6, 0.1))
	tw.tween_property(m, "albedo_color:a", 0.0, 0.35)


func _flash(col: Color, energy: float) -> void:
	var l: OmniLight3D = OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = 14.0
	add_child(l)
	var tw: Tween = create_tween()
	tw.tween_property(l, "light_energy", 0.0, lifetime * 0.6)
