extends "res://qa/scenarios/qa_scenario.gd"
## Loads every .gd and .tscn under res:// (skips .godot, qa/evidence).

var _loaded: int = 0
var _failed: Array[String] = []


func run() -> void:
	_scan("res://")
	metrics["loaded"] = _loaded
	metrics["failed"] = _failed
	for f: String in _failed:
		fail("load failed: " + f)
	await frames(1)


func _scan(dir_path: String) -> void:
	var d: DirAccess = DirAccess.open(dir_path)
	if d == null:
		return
	d.include_hidden = false
	for sub: String in d.get_directories():
		if sub.begins_with(".") or sub == "evidence" or sub == "addons":
			continue
		_scan(dir_path.path_join(sub))
	for file: String in d.get_files():
		var ext: String = file.get_extension()
		if ext != "gd" and ext != "tscn":
			continue
		var path: String = dir_path.path_join(file)
		var res: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE)
		if res == null:
			_failed.append(path)
		elif res is GDScript and not (res as GDScript).can_instantiate() and not (res as GDScript).is_abstract():
			_failed.append(path + " (script does not compile)")
		else:
			_loaded += 1
