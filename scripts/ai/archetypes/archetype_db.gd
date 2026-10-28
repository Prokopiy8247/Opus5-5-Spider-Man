class_name ArchetypeDB
extends RefCounted
## Static access to data/enemies/archetypes.json. Unknown ids fall back to "thug".

const DATA_PATH: String = "res://data/enemies/archetypes.json"

static var _cache: Dictionary = {}


static func get_config(id: StringName) -> Dictionary:
	if _cache.is_empty():
		var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if raw is Array:
			for v: Variant in raw:
				if v is Dictionary:
					_cache[StringName(str((v as Dictionary)["id"]))] = v
	if _cache.has(id):
		return (_cache[id] as Dictionary).duplicate()
	return (_cache.get(&"thug", {}) as Dictionary).duplicate()


static func ids() -> Array[StringName]:
	get_config(&"thug")
	var out: Array[StringName] = []
	for k: Variant in _cache.keys():
		out.append(k as StringName)
	return out


## True when a hit coming from `attacker_pos` is blocked by a front shield.
static func blocks_hit(enemy: Node3D, attacker_pos: Vector3) -> bool:
	if not bool(get_config(StringName(str(enemy.get(&"archetype")))).get("block_front", false)):
		return false
	var to: Vector3 = attacker_pos - enemy.global_position
	to.y = 0.0
	return to.length() > 0.01 and to.normalized().dot(-enemy.global_basis.z) > 0.3
