class_name ChunkStreamer
extends Node
## Reversible chunk streaming on a 128 m XZ grid. Nodes registered here are hidden and
## PROCESS_MODE_DISABLED when their chunk leaves the (2*LOAD_RADIUS+1)^2 square around the
## focus, and restored (visible + previous process_mode) when it comes back. Nothing is freed.
## Nodes in group "stream_always" are never unloaded. Work happens only when the focus chunk changes.

signal chunk_loaded(coord: Vector2i)
signal chunk_unloaded(coord: Vector2i)

const CHUNK_SIZE: float = 128.0
const LOAD_RADIUS: int = 2

var _chunks: Dictionary = {}        # Vector2i -> Array[Node3D]
var _loaded: Dictionary = {}        # Vector2i -> true
var _saved_mode: Dictionary = {}    # instance_id -> ProcessMode before unload
var _focus: Vector2i = Vector2i.ZERO
var _has_focus: bool = false


func chunk_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / CHUNK_SIZE), floori(pos.z / CHUNK_SIZE))


## Puts n into the chunk of its global_position. Merged meshes built at the origin can pass their
## real centre via set_meta(&"stream_center", Vector3) before registering.
func register_node(n: Node3D) -> void:
	if n == null:
		return
	var p: Vector3 = n.get_meta(&"stream_center", n.global_position) if n.is_inside_tree() else n.get_meta(&"stream_center", n.position)
	var c: Vector2i = chunk_of(p)
	if not _chunks.has(c):
		var arr: Array[Node3D] = []
		_chunks[c] = arr
		_loaded[c] = true  # new chunks start loaded; next focus check decides
	(_chunks[c] as Array[Node3D]).append(n)
	if _has_focus:
		var inside: bool = _in_range(c, _focus)
		if inside and not _loaded.has(c):
			_loaded[c] = true
		elif not inside:
			_loaded.erase(c)
			_unload_node(n)


func update_focus(pos: Vector3) -> void:
	var c: Vector2i = chunk_of(pos)
	if _has_focus and c == _focus:
		return
	_has_focus = true
	_focus = c
	for k: Vector2i in _chunks:
		var want: bool = _in_range(k, c)
		var is_on: bool = _loaded.has(k)
		if want and not is_on:
			_loaded[k] = true
			for n: Node3D in _chunks[k]:
				_load_node(n)
			chunk_loaded.emit(k)
		elif not want and is_on:
			_loaded.erase(k)
			for n: Node3D in _chunks[k]:
				_unload_node(n)
			chunk_unloaded.emit(k)


func get_loaded_chunk_count() -> int:
	return _loaded.size()


func get_total_chunk_count() -> int:
	return _chunks.size()


## Empty chunks (park, river) hold no nodes but still count as loaded inside the focus square.
func is_chunk_loaded(c: Vector2i) -> bool:
	if _loaded.has(c):
		return true
	return _has_focus and not _chunks.has(c) and _in_range(c, _focus)


func _in_range(k: Vector2i, f: Vector2i) -> bool:
	return absi(k.x - f.x) <= LOAD_RADIUS and absi(k.y - f.y) <= LOAD_RADIUS


func _unload_node(n: Node3D) -> void:
	if not is_instance_valid(n) or n.is_in_group(&"stream_always"):
		return
	var id: int = n.get_instance_id()
	if _saved_mode.has(id):
		return
	_saved_mode[id] = n.process_mode
	n.visible = false
	n.process_mode = Node.PROCESS_MODE_DISABLED


func _load_node(n: Node3D) -> void:
	if not is_instance_valid(n):
		return
	var id: int = n.get_instance_id()
	if not _saved_mode.has(id):
		return
	n.process_mode = _saved_mode[id] as Node.ProcessMode
	_saved_mode.erase(id)
	n.visible = true
