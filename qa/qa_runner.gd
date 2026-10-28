extends Node
## QA autoload (registered as "QA"). Completely inert unless the game is
## started with a user arg `--qa=<scenario>`, e.g.
##   godot --path <project> -- --qa=smoke
## Without the flag it prints nothing, connects nothing and disables processing.

const SCENARIOS: Dictionary = {
	"smoke": "res://qa/scenarios/smoke.gd",
	"load_all": "res://qa/scenarios/load_all.gd",
	"traversal_bot": "res://qa/scenarios/traversal_bot.gd",
	"city_flythrough": "res://qa/scenarios/city_flythrough.gd",
	"combat_bot": "res://qa/scenarios/combat_bot.gd",
	"animation_gallery": "res://qa/scenarios/animation_gallery.gd",
	"perf_sweep": "res://qa/scenarios/perf_sweep.gd",
	"regression": "res://qa/scenarios/regression.gd",
	"soak10": "res://qa/scenarios/soak10.gd",
	"gadget_bot": "res://qa/scenarios/gadget_bot.gd",
	"progression_bot": "res://qa/scenarios/progression_bot.gd",
	"stealth_bot": "res://qa/scenarios/stealth_bot.gd",
	"base_waves": "res://qa/scenarios/base_waves.gd",
}

var scenario_name: String = ""
var active: bool = false


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--qa="):
			scenario_name = arg.substr(5).strip_edges()
	if scenario_name.is_empty():
		set_process(false)
		set_physics_process(false)
		return
	active = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	_start.call_deferred()


func _start() -> void:
	var path: String = SCENARIOS.get(scenario_name, "")
	var script: Script = load(path) as Script if not path.is_empty() else null
	if script == null:
		# Unknown scenario: still write evidence so the failure is visible.
		script = load("res://qa/scenarios/qa_scenario.gd") as Script
	var scenario: Node = script.new() as Node
	scenario.name = "QAScenario"
	add_child(scenario)
	var extra: Dictionary = scenario.get("EXTRA_SCENARIOS") as Dictionary
	if path.is_empty() and not extra.has(scenario_name):
		scenario.call("fail", "unknown scenario '%s'" % scenario_name)
	scenario.call("begin", scenario_name)
