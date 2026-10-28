# Contracts

Typed GDScript, English UI, only the names and signals listed here.

## Input actions (project.godot)
`gadget_use`=G, `gadget_next`=Tab, `open_skills`=K, `open_suits`=L, `open_map`=M.

## Events (scripts/core/events.gd)
`gadget_used(id)`, `skill_unlocked(id)`, `suit_changed(id)`, `base_alarm(base_id)`, `base_cleared(base_id)`, `wave_started(base_id, wave)`, `hit_landed(target, damage, combo)`.

## Gadgets
`Gadget` (`id`, `display_name`, `cooldown_s`, `activate(player) -> bool`); `GadgetManager` child of Player: `use_current()`, `next()`, `get_slots()`.
IDs: web_bomb, impact_web, trip_mine, electric_web, suspension_matrix.

## Progression
`data/progression/skills.json` (>=12 entries `{id,name,cost,requires,effect{stat:mult}}`), autoload `Skills` (SkillTree), autoload `Suits`. QA runs save to `user://progress_qa.json`.

## Chunk streaming (scripts/world/streaming/chunk_streamer.gd)
`ChunkStreamer extends Node`, `CHUNK_SIZE=128.0`, `LOAD_RADIUS=2` (5x5). `chunk_of`, `register_node`, `update_focus`, `get_loaded_chunk_count`, `get_total_chunk_count`, `is_chunk_loaded`; signals `chunk_loaded`, `chunk_unloaded`. Unload = `visible=false` + `PROCESS_MODE_DISABLED`, reversible. Group `stream_always` is never unloaded. Optional meta `stream_center` overrides position. Group `chunk_streamer`.
World registers building meshes (128 m chunks) and zip points; `Chunk_*` collision bodies are not streamed.

## Traffic (scripts/world/traffic/)
`TrafficManager extends Node3D`: `setup(lanes, max_cars=40)`, `get_active_car_count()`, `set_focus(pos)` (300 m). `TrafficCar extends Node3D`, procedural meshes, groups `traffic_car` + `stream_always`, 8-14 m/s, stops for player/car within 6 m ahead. Manager is in group `traffic_manager`; lanes = closed loops along every avenue.

## QA scenarios
`qa/scenarios/*.gd` extend qa_scenario.gd; write `qa/evidence/<name>/metrics.json` with `pass`, `duration_s`, `checks`, screenshots `NN_name.png`. New ones are registered in `EXTRA_SCENARIOS`. Run: `--qa=<name>`, all: `qa/tools/run_all.ps1`.
