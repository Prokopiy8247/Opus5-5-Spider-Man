extends "res://qa/scenarios/qa_scenario.gd"
## Builds a HeroVisual (loads assets/models/hero.glb) on its own lit stage and plays every
## contract clip. Pass: glb has a skeleton and all 17 contract clips exist by name.

const CLIPS: Array[StringName] = [
	&"idle", &"run", &"sprint", &"jump", &"fall", &"swing", &"zip", &"wall_run", &"land_hero",
	&"roll", &"punch_1", &"punch_2", &"punch_3", &"dodge", &"finisher", &"hit", &"death",
]


func run() -> void:
	# Freeze and hide the game; restored at the end so regression's later scenarios still run.
	var cur: Node = get_tree().current_scene
	var prev_mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT
	var hidden: Array[Node] = []
	if cur != null:
		prev_mode = cur.process_mode
		cur.process_mode = Node.PROCESS_MODE_DISABLED
		for c: Node in cur.get_children():
			if (c is Node3D and (c as Node3D).visible) or (c is CanvasLayer and (c as CanvasLayer).visible):
				c.set(&"visible", false)
				hidden.append(c)
	var stage := Node3D.new()
	stage.name = "QAGallery"
	add_child(stage)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.18, 0.2, 0.24)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.65)
	env.environment = e
	stage.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	stage.add_child(sun)
	var cam := Camera3D.new()
	stage.add_child(cam)
	cam.position = Vector3(0, 1.2, 4.0)
	cam.look_at(Vector3(0, 1.0, 0))
	cam.make_current()
	var hero: Node3D = (load("res://scripts/ui/hero_visual.gd") as GDScript).new() as Node3D
	hero.rotation.y = PI
	stage.add_child(hero)
	var anim: AnimationPlayer = hero.get(&"anim_player") as AnimationPlayer
	var has_skel: bool = hero.get(&"skeleton") != null
	var missing: Array[String] = []
	for clip: StringName in CLIPS:
		if anim == null or not anim.has_animation(clip):
			missing.append(String(clip))
		hero.call(&"play", clip, 0.0)
		await seconds(0.35)
		await screenshot(String(clip))
	metrics["clips_total"] = CLIPS.size()
	metrics["clips_found"] = CLIPS.size() - missing.size()
	metrics["clips_missing"] = missing
	metrics["glb_skeleton"] = has_skel
	if not has_skel:
		fail("hero.glb not loaded (no Skeleton3D)")
	if not missing.is_empty():
		fail("%d clips missing: %s" % [missing.size(), ", ".join(missing)])
	stage.queue_free()
	if cur != null and is_instance_valid(cur):
		cur.process_mode = prev_mode
		for c: Node in hidden:
			if is_instance_valid(c):
				c.set(&"visible", true)
		var gcam: Camera3D = get_viewport().get_camera_3d()
		var p: Node = get_player()
		if p != null:
			var pc: Camera3D = null
			for n: Node in p.find_children("*", "Camera3D", true, false):
				pc = n as Camera3D
			if pc != null and pc != gcam:
				pc.make_current()
