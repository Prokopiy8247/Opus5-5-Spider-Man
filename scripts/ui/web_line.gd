class_name WebLine
extends MeshInstance3D
## Thin camera-facing web strip from hand to anchor. Contract: set_points(from, to, tension), fade_out().

const SEGMENTS: int = 24
const WIDTH: float = 0.035

var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
var _tension: float = 1.0
var _alpha: float = 1.0
var _fading: bool = false
var _imesh: ImmediateMesh = ImmediateMesh.new()
var _mat: ShaderMaterial = ShaderMaterial.new()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	mesh = _imesh
	_mat.shader = load("res://shaders/web.gdshader") as Shader
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	extra_cull_margin = 1000.0


func play() -> void:
	_fading = false
	_alpha = 1.0
	visible = true


func set_points(from: Vector3, to: Vector3, tension: float) -> void:
	_from = from
	_to = to
	_tension = clampf(tension, 0.0, 1.0)
	if not _fading:
		_alpha = 1.0
		visible = true
	_rebuild()


func fade_out() -> void:
	_fading = true


func _process(delta: float) -> void:
	if _fading:
		_alpha -= delta * 6.0
		if _alpha <= 0.0:
			visible = false
			_fading = false
			_alpha = 0.0
	_mat.set_shader_parameter("alpha_mul", _alpha)
	_mat.set_shader_parameter("tremble", lerpf(0.06, 0.008, _tension))


func _rebuild() -> void:
	_imesh.clear_surfaces()
	var cam: Camera3D = get_viewport().get_camera_3d() if is_inside_tree() else null
	var cam_pos: Vector3 = cam.global_position if cam else _from + Vector3.UP * 3.0
	var dir: Vector3 = _to - _from
	if dir.length_squared() < 0.0001:
		return
	var sag: float = (1.0 - _tension) * dir.length() * 0.08
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i: int in range(SEGMENTS + 1):
		var t: float = float(i) / float(SEGMENTS)
		var p: Vector3 = _from.lerp(_to, t) + Vector3.DOWN * sag * sin(t * PI)
		var side: Vector3 = dir.cross(cam_pos - p).normalized() * WIDTH * lerpf(1.0, 0.6, t)
		var n: Vector3 = (cam_pos - p).normalized()
		_imesh.surface_set_normal(n)
		_imesh.surface_set_uv(Vector2(t, 0.0))
		_imesh.surface_add_vertex(p - side)
		_imesh.surface_set_normal(n)
		_imesh.surface_set_uv(Vector2(t, 1.0))
		_imesh.surface_add_vertex(p + side)
	_imesh.surface_end()
