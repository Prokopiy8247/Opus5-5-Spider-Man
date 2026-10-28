class_name HumanoidVisual
extends Node3D
## Shared base for HeroVisual and EnemyVisual. Loads a glb (if present), re-hosts its animations on
## the child AnimationPlayer named "AnimationPlayer", and otherwise builds a capsule humanoid with
## procedural poses. Missing clips never raise errors: they fall back to a procedural pose.

const BONES: PackedStringArray = ["Hips", "Spine", "Chest", "Neck", "Head"]

var model_path: String = ""
var body_color: Color = Color(0.75, 0.08, 0.1)
var limb_color: Color = Color(0.1, 0.18, 0.55)

var anim_player: AnimationPlayer
var skeleton: Skeleton3D = null
var model: Node3D = null
var current_anim: StringName = &"idle"
var _lean: Vector3 = Vector3.ZERO
var _lean_smooth: Vector3 = Vector3.ZERO
var _reach: Dictionary = {}          # hand StringName -> Vector3 world pos
var _reach_w: Dictionary = {&"L": 0.0, &"R": 0.0}
var _t: float = 0.0
var _parts: Dictionary = {}          # fallback joints: name -> Node3D
var _hand_l: Node3D
var _hand_r: Node3D
var _facing: Node3D = null           # pivot holding the model (rotated PI for glb models)
var _face_local: Vector3 = Vector3.FORWARD  # model-space face direction


func _ready() -> void:
	anim_player = get_node_or_null(^"AnimationPlayer") as AnimationPlayer
	if anim_player == null:
		anim_player = AnimationPlayer.new()
		anim_player.name = "AnimationPlayer"
		add_child(anim_player)
	anim_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	if model_path != "" and ResourceLoader.exists(model_path):
		_setup_model(load(model_path) as PackedScene)
	if skeleton == null:
		_build_fallback()
	play(&"idle", 0.0)


# ---------------- public API (contract) ----------------

## Gameplay clip names -> the 17 contract clips baked into hero.glb / enemy.glb.
const ALIASES: Dictionary = {
	&"walk": &"run", &"land": &"land_hero", &"hero_land": &"land_hero", &"perch": &"idle",
	&"search": &"idle", &"mantle": &"jump", &"dive": &"fall", &"free_fall": &"fall",
	&"point_launch": &"jump", &"launched": &"fall", &"swing_start": &"swing",
	&"swing_loop_a": &"swing", &"swing_loop_b": &"swing", &"swing_release": &"jump",
	&"web_shoot": &"punch_1", &"wall_run_l": &"wall_run", &"wall_run_r": &"wall_run",
	&"wall_run_up": &"wall_run", &"air_trick_1": &"roll", &"air_trick_2": &"roll",
	&"dodge_f": &"dodge", &"dodge_b": &"dodge", &"dodge_l": &"dodge", &"dodge_r": &"dodge",
	&"combo_1": &"punch_1", &"combo_2": &"punch_2", &"combo_3": &"punch_3",
	&"combo_4": &"punch_1", &"combo_5": &"punch_3", &"launcher": &"punch_3",
	&"web_strike": &"punch_2", &"swing_kick": &"punch_3", &"grab": &"punch_1",
	&"throw": &"punch_2", &"whip": &"punch_2", &"shoot": &"punch_1",
	&"attack_light": &"punch_1", &"attack_heavy": &"punch_3", &"finisher_1": &"finisher",
	&"finisher_2": &"finisher", &"takedown_perch": &"finisher", &"takedown_ledge": &"finisher",
	&"hurt": &"hit", &"webbed": &"hit", &"shield_block": &"hit", &"ko": &"ko_back",
	&"death": &"ko_back",
}
## Aliases that win even when the source name exists in the glb (death is kept only as a copy).
const PREFERRED: Array[StringName] = [&"ko", &"death"]
## Older enemy.glb builds lack ko_*: fall back to the legacy death clip.
const KO_FALLBACK: StringName = &"death"
const KO_KINDS: Array[StringName] = [&"back", &"front", &"side", &"heavy"]
const LOOPING: Array[StringName] = [&"idle", &"run", &"sprint", &"fall", &"swing", &"zip", &"wall_run"]

var _locked: bool = false


## Contract name for play(). A finished one-shot clip holds its last frame until the next call.
func play_clip(clip_name: StringName, blend: float = 0.15) -> void:
	play(clip_name, blend)


## Plays ko_<kind> and locks the visual: later play()/play_clip() calls are ignored.
func play_ko(kind: StringName) -> void:
	var k: StringName = kind if KO_KINDS.has(kind) else &"back"
	_locked = false
	var clip: StringName = StringName("ko_" + String(k))
	if skeleton != null and not anim_player.has_animation(clip):
		clip = clip if not anim_player.has_animation(KO_FALLBACK) else KO_FALLBACK
	_play_resolved(StringName("ko_" + String(k)), clip, 0.1)
	_locked = true


func is_locked() -> bool:
	return _locked


func get_current_clip() -> StringName:
	return current_anim


func play(anim: StringName, blend: float = 0.15) -> void:
	if _locked:
		return
	var clip: StringName = anim
	if skeleton != null:
		var alias: StringName = ALIASES.get(anim, anim)
		if PREFERRED.has(anim) and anim_player.has_animation(alias):
			clip = alias
		elif not anim_player.has_animation(clip):
			clip = alias
	if current_anim == anim and skeleton != null and anim_player.is_playing():
		return
	_play_resolved(anim, clip, blend)


func _play_resolved(anim: StringName, clip: StringName, blend: float) -> void:
	current_anim = anim
	if skeleton != null and anim_player.has_animation(clip):
		if anim_player.current_animation != String(clip) or not anim_player.is_playing():
			anim_player.play(clip, blend)
	elif anim_player.is_playing():
		anim_player.stop(true)  # keep_state: never snap to rest
	_t = 0.0


func set_lean(v: Vector3) -> void:
	_lean = v.clamp(Vector3(-0.6, -0.6, -0.6), Vector3(0.6, 0.6, 0.6))


func set_reach_target(hand: StringName, world_pos: Vector3) -> void:
	var key: StringName = &"L" if String(hand).to_upper().begins_with("L") else &"R"
	if world_pos == Vector3.INF or not world_pos.is_finite():
		_reach.erase(key)
	else:
		_reach[key] = world_pos


## World-space horizontal unit vector the model's face points to (-Z of the visual root after the flip).
func get_facing_dir() -> Vector3:
	var face: Vector3 = -global_basis.z
	if model != null and model.is_inside_tree():
		face = model.global_basis * _face_local
	face.y = 0.0
	if face.length_squared() < 1e-6:
		face = -global_basis.z
		face.y = 0.0
	return face.normalized() if face.length_squared() > 1e-6 else Vector3.FORWARD


func get_hand(hand: StringName) -> Node3D:
	return _hand_l if String(hand).to_upper().begins_with("L") else _hand_r


# ---------------- model path ----------------

func _setup_model(ps: PackedScene) -> void:
	if ps == null:
		return
	model = ps.instantiate() as Node3D
	if model == null:
		return
	model.name = "Model"
	# hero.glb / enemy.glb face +Z, gameplay forward is -basis.z: turn the model root by PI once.
	# Per-frame lean is written to model.rotation, so the flip lives on this parent pivot.
	_facing = Node3D.new()
	_facing.name = "Facing"
	_facing.rotation = Vector3(0.0, PI, 0.0)
	add_child(_facing)
	_facing.add_child(model)
	_face_local = Vector3.BACK  # +Z in model space
	skeleton = _find_type(model, "Skeleton3D") as Skeleton3D
	if skeleton == null:
		return
	var src: AnimationPlayer = _find_type(model, "AnimationPlayer") as AnimationPlayer
	if src != null:
		var src_root: Node = src.get_node(src.root_node)
		for lib_name: StringName in src.get_animation_library_list():
			var lib: AnimationLibrary = src.get_animation_library(lib_name)
			for a: StringName in lib.get_animation_list():
				var anm: Animation = lib.get_animation(a)
				anm.loop_mode = Animation.LOOP_LINEAR if LOOPING.has(a) else Animation.LOOP_NONE
			if not anim_player.has_animation_library(lib_name):
				anim_player.add_animation_library(lib_name, lib)
		src.stop()
		src.active = false
		anim_player.root_node = anim_player.get_path_to(src_root)
	_hand_l = _attach(&"HandL", "Hand.L")
	_hand_r = _attach(&"HandR", "Hand.R")
	_apply_suit_to_model()


func _attach(n: StringName, bone: String) -> Node3D:
	var ba: BoneAttachment3D = BoneAttachment3D.new()
	ba.name = n
	skeleton.add_child(ba)
	if skeleton.find_bone(bone) >= 0:
		ba.bone_name = bone
	return ba


func _apply_suit_to_model() -> void:
	pass  # overridden


func _find_type(n: Node, type_name: String) -> Node:
	if n.is_class(type_name):
		return n
	for c: Node in n.get_children():
		var r: Node = _find_type(c, type_name)
		if r != null:
			return r
	return null


# ---------------- per-frame ----------------

func _process(delta: float) -> void:
	_t += delta
	_lean_smooth = _lean_smooth.lerp(_lean, clampf(delta * 8.0, 0.0, 1.0))
	for k: StringName in [&"L", &"R"]:
		var target: float = 1.0 if _reach.has(k) else 0.0
		_reach_w[k] = move_toward(float(_reach_w[k]), target, delta * 6.0)
	if skeleton != null:
		# A finished one-shot clip leaves its last frame applied; never reset to rest here.
		if anim_player.is_playing():
			anim_player.advance(delta)
		# Lean is given in the gameplay frame (-Z forward); the model sits under a PI-flipped
		# pivot, so pitch and roll change sign in model space.
		model.rotation = Vector3(-_lean_smooth.x, _lean_smooth.y, -_lean_smooth.z)
		_apply_reach_skeleton()
	else:
		_fallback_pose()


func _apply_reach_skeleton() -> void:
	for k: StringName in [&"L", &"R"]:
		var w: float = float(_reach_w[k])
		if w <= 0.001 or not _reach.has(k):
			continue
		var b: int = skeleton.find_bone("UpperArm." + String(k))
		var lb: int = skeleton.find_bone("LowerArm." + String(k))
		if b < 0:
			continue
		var gp: Transform3D = skeleton.get_bone_global_pose(b)
		var tgt: Vector3 = skeleton.global_transform.affine_inverse() * (_reach[k] as Vector3)
		var dir: Vector3 = (tgt - gp.origin).normalized()
		var axis: Vector3 = gp.basis.y.normalized()
		if dir.is_zero_approx() or axis.cross(dir).is_zero_approx():
			continue
		var q: Quaternion = Quaternion(axis, dir)
		q = Quaternion.IDENTITY.slerp(q, w)
		var new_basis: Basis = Basis(q) * gp.basis
		var parent: int = skeleton.get_bone_parent(b)
		var pg: Basis = skeleton.get_bone_global_pose(parent).basis if parent >= 0 else Basis.IDENTITY
		skeleton.set_bone_pose_rotation(b, (pg.inverse() * new_basis).get_rotation_quaternion())
		if lb >= 0:
			var rest: Quaternion = skeleton.get_bone_rest(lb).basis.get_rotation_quaternion()
			skeleton.set_bone_pose_rotation(lb, skeleton.get_bone_pose_rotation(lb).slerp(rest, w))


# ---------------- fallback capsule humanoid ----------------

func _mat(c: Color) -> StandardMaterial3D:
	var m: StandardMaterial3D = StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.55
	return m


func _joint(n: String, parent: Node3D, pos: Vector3) -> Node3D:
	var j: Node3D = Node3D.new()
	j.name = n
	j.position = pos
	parent.add_child(j)
	_parts[n] = j
	return j


func _capsule(parent: Node3D, length: float, radius: float, c: Color) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cm: CapsuleMesh = CapsuleMesh.new()
	cm.radius = radius
	cm.height = maxf(length, radius * 2.0)
	cm.radial_segments = 12
	cm.rings = 4
	mi.mesh = cm
	mi.position = Vector3(0.0, -length * 0.5, 0.0)
	mi.material_override = _mat(c)
	parent.add_child(mi)


func _build_fallback() -> void:
	var root: Node3D = Node3D.new()
	root.name = "Fallback"
	add_child(root)
	model = root
	var hips: Node3D = _joint("Hips", root, Vector3(0, 0.95, 0))
	var chest: Node3D = _joint("Chest", hips, Vector3(0, 0.05, 0))
	var torso: MeshInstance3D = MeshInstance3D.new()
	var tm: CapsuleMesh = CapsuleMesh.new()
	tm.radius = 0.17
	tm.height = 0.62
	torso.mesh = tm
	torso.position = Vector3(0, 0.25, 0)
	torso.material_override = _mat(body_color)
	chest.add_child(torso)
	var head: Node3D = _joint("Head", chest, Vector3(0, 0.62, 0))
	var hm: MeshInstance3D = MeshInstance3D.new()
	var sm: SphereMesh = SphereMesh.new()
	sm.radius = 0.12
	sm.height = 0.27
	hm.mesh = sm
	hm.position = Vector3(0, 0.1, 0)
	hm.material_override = _mat(body_color)
	head.add_child(hm)
	_decorate_fallback(head, chest)
	for s: String in ["L", "R"]:
		var sx: float = 1.0 if s == "L" else -1.0
		var ua: Node3D = _joint(s + "_UpperArm", chest, Vector3(0.22 * sx, 0.5, 0))
		_capsule(ua, 0.3, 0.055, limb_color)
		var la: Node3D = _joint(s + "_LowerArm", ua, Vector3(0, -0.3, 0))
		_capsule(la, 0.28, 0.048, body_color)
		var hand: Node3D = _joint(s + "_Hand", la, Vector3(0, -0.3, 0))
		var hn: Node3D = Node3D.new()
		hn.name = "Hand" + s
		hand.add_child(hn)
		if s == "L":
			_hand_l = hn
		else:
			_hand_r = hn
		var ul: Node3D = _joint(s + "_UpperLeg", hips, Vector3(0.1 * sx, -0.02, 0))
		_capsule(ul, 0.44, 0.075, limb_color)
		var ll: Node3D = _joint(s + "_LowerLeg", ul, Vector3(0, -0.44, 0))
		_capsule(ll, 0.44, 0.06, body_color)


func _decorate_fallback(_head: Node3D, _chest: Node3D) -> void:
	pass  # overridden


func _p(n: String) -> Node3D:
	return _parts.get(n) as Node3D


## Procedural pose keyed on the animation name. Rotations are in radians (x = pitch forward).
func _fallback_pose() -> void:
	var a: String = String(current_anim)
	var t: float = _t
	var arm_l: Vector3 = Vector3(0, 0, 0.12)
	var arm_r: Vector3 = Vector3(0, 0, -0.12)
	var fore_l: float = -0.2
	var fore_r: float = -0.2
	var leg_l: float = 0.0
	var leg_r: float = 0.0
	var knee_l: float = 0.0
	var knee_r: float = 0.0
	var spine: float = 0.0
	var hip_y: float = 0.95
	var breathe: float = sin(t * 2.0) * 0.02
	if a in ["run", "sprint", "walk", "wall_run_l", "wall_run_r", "wall_run_up"]:
		var f: float = 11.0 if a == "sprint" else (5.0 if a == "walk" else 9.0)
		var amp: float = 0.9 if a == "sprint" else (0.4 if a == "walk" else 0.7)
		var s: float = sin(t * f)
		leg_l = s * amp; leg_r = -s * amp
		knee_l = maxf(0.0, -cos(t * f)) * 1.2; knee_r = maxf(0.0, cos(t * f)) * 1.2
		arm_l.x = -s * amp; arm_r.x = s * amp
		fore_l = -0.9; fore_r = -0.9
		spine = 0.25 if a == "sprint" else 0.1
		hip_y = 0.93 + absf(cos(t * f)) * 0.04
	elif a.begins_with("swing") or a == "zip" or a == "web_shoot":
		var s2: float = sin(t * 2.5)
		arm_r = Vector3(-2.9, 0, -0.1); fore_r = 0.0
		arm_l = Vector3(-0.4 + s2 * 0.3, 0, 0.5); fore_l = -0.6
		leg_l = 0.5 + s2 * 0.3; knee_l = 1.0
		leg_r = 0.1 - s2 * 0.3; knee_r = 0.4
		spine = -0.1
	elif a in ["fall", "dive", "jump", "point_launch", "free_fall", "launched"]:
		var s3: float = sin(t * 6.0) * 0.15
		arm_l = Vector3(-1.2, 0, 1.0 + s3); arm_r = Vector3(-1.2, 0, -1.0 - s3)
		leg_l = 0.4; leg_r = -0.2; knee_l = 0.8; knee_r = 0.3
		spine = 0.5 if a == "dive" else 0.1
	elif a in ["land", "hero_land", "perch", "roll", "mantle", "search"]:
		leg_l = 1.2; leg_r = 0.6; knee_l = 1.8; knee_r = 1.9
		hip_y = 0.55; spine = 0.5
		arm_r = Vector3(-0.3, 0, -0.3); fore_r = -0.4
		if a == "hero_land":
			arm_r = Vector3(-0.2, 0, -0.1); fore_r = 0.0
	elif a.begins_with("combo") or a.begins_with("attack") or a in ["launcher", "web_strike", "swing_kick", "throw", "grab", "whip", "shoot"] or a.begins_with("finisher") or a.begins_with("takedown"):
		var ph: float = clampf(t * 4.0, 0.0, 1.0)
		var right: bool = a.ends_with("1") or a.ends_with("3") or a.ends_with("5") or a == "attack_heavy"
		var punch: Vector3 = Vector3(-1.5 * ph, 0, 0)
		if right:
			arm_r = punch; fore_r = -1.2 * (1.0 - ph)
		else:
			arm_l = punch; fore_l = -1.2 * (1.0 - ph)
		leg_l = 0.4; leg_r = -0.3; knee_l = 0.5; knee_r = 0.2
		spine = 0.15
	elif a in ["hurt", "webbed", "shield_block", "death"] or a.begins_with("ko"):
		spine = -0.3
		arm_l = Vector3(-0.8, 0, 0.4); arm_r = Vector3(-0.8, 0, -0.4)
		fore_l = -1.4; fore_r = -1.4
		if a == "death" or a.begins_with("ko"):
			hip_y = 0.2
	elif a.begins_with("dodge") or a.begins_with("air_trick"):
		spine = 0.6; leg_l = 1.4; leg_r = 1.4; knee_l = 2.0; knee_r = 2.0; hip_y = 0.7
		arm_l = Vector3(-0.5, 0, 0.8); arm_r = Vector3(-0.5, 0, -0.8)
	var hips: Node3D = _p("Hips")
	if hips == null:
		return
	hips.position.y = lerpf(hips.position.y, hip_y, 0.25)
	model.rotation = _lean_smooth
	if a.begins_with("air_trick"):
		model.rotation.x += t * 9.0
	elif a == "death" or a.begins_with("ko"):
		model.rotation.x = lerpf(model.rotation.x, -1.5, 0.2)
	_lerp_rot(_p("Chest"), Vector3(spine + breathe, 0, 0))
	_lerp_rot(_p("L_UpperArm"), arm_l)
	_lerp_rot(_p("R_UpperArm"), arm_r)
	_lerp_rot(_p("L_LowerArm"), Vector3(fore_l, 0, 0))
	_lerp_rot(_p("R_LowerArm"), Vector3(fore_r, 0, 0))
	_lerp_rot(_p("L_UpperLeg"), Vector3(-leg_l, 0, 0))
	_lerp_rot(_p("R_UpperLeg"), Vector3(-leg_r, 0, 0))
	_lerp_rot(_p("L_LowerLeg"), Vector3(knee_l, 0, 0))
	_lerp_rot(_p("R_LowerLeg"), Vector3(knee_r, 0, 0))
	# Hand reach: aim the upper arm at the target (arm hangs along -Y).
	for k: StringName in [&"L", &"R"]:
		var w: float = float(_reach_w[k])
		var ua: Node3D = _p(String(k) + "_UpperArm")
		if w <= 0.001 or ua == null or not _reach.has(k):
			continue
		var to_t: Vector3 = (_reach[k] as Vector3) - ua.global_position
		if to_t.length_squared() < 0.01:
			continue
		var cur: Basis = ua.global_basis.orthonormalized()
		var want: Basis = Basis(Quaternion(-cur.y, to_t.normalized())) * cur
		ua.global_basis = cur.slerp(want, w)
		var la: Node3D = _p(String(k) + "_LowerArm")
		la.rotation = la.rotation.lerp(Vector3.ZERO, w)


func _lerp_rot(n: Node3D, r: Vector3) -> void:
	if n != null:
		n.rotation = n.rotation.lerp(r, 0.25)
