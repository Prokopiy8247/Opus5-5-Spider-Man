# Bugs

Severity: **P0** crash / fall below y=-50 / blocker, **P1** broken mechanic, **P2** cosmetic.
Status: open → fixed (assignee) → verified (QA) → closed (Team Lead).

| id | severity | title | steps | evidence | owner | status |
|---|---|---|---|---|---|---|
| BUG-001 | P2 | "6 ObjectDB instances were leaked at exit" WARNING after QA runs | `-- --qa=combat_bot` or `load_all`, read stdout at exit | console output | Lead | verified: `--verbose` showed 3 AudioStreamWAV + 3 AudioStreamPlaybackWAV from the looping Sfx players; `audio_synth.gd` now stops players and drops streams on exit. Full `run_all.ps1`: 13/13 logs clean |
| BUG-002 | P1 | `run_all.ps1` reported PASS for scenarios cut off by `--quit-after` (no metrics.json) | run perf_sweep with limit 8000 at ~500 FPS | first run_all table: exit 0 but no metrics | Lead | verified: frame limits raised, missing/false metrics.json now fails the run |
| BUG-003 | P1 | animation_gallery left the game scene disabled, so later regression sub-scenarios failed | `--qa=regression` | gadget_bot 0 gadgets, base_waves 0 waves inside regression | Lead | verified: scene restored after gallery, regression 8/8 |
| BUG-004 | P1 | progression_bot failed on second run: skills persisted in user://progress.json from the previous run | run `--qa=progression_bot` twice | "only 0 skills unlocked" | Lead | verified: QA runs use a fresh user://progress_qa.json; 2 runs in a row pass |
| BUG-005 | P1 | "Trying to cast a freed object" spam in EnemyBase._update_patrol after a patrol enemy is freed | `--qa=damage_bot` (frees enemies at base) | 8110 ERROR lines in damage_bot.log | Lead | verified: validity checked on the raw Variant before the cast; run_all 16/16 clean |
| BUG-006 | P1 | damage_bot landed no hits: thug spawned 3.5 m sideways and bot also freed base guards | `--qa=damage_bot` | damage_level0 = -1 | Lead | verified: own thug spawned 2 m ahead; damage 10.0 -> 12.5 |
| BUG-007 | P2 | is_chunk_loaded false for empty chunks (park) inside the 5x5 square | `--qa=world_stream_bot` step 3 | player_chunk_loaded=false | Lead | verified: empty in-range chunks count as loaded; world_stream_bot PASS |
| BUG-008 | P2 | Spurious "[QA] FAIL: unknown scenario" line for EXTRA_SCENARIOS | any `--qa=damage_bot` | log line 4 | Lead | verified: qa_runner checks EXTRA_SCENARIOS |

## Iteration 2: "before" state (recorded by QA before the fixes)

The QA worker could not open images (view_image is not available to workers), so the lead must look at both pictures and confirm or correct these notes. The descriptions come from the brief and the code at commit c3d46e3.

| id | severity | title | steps | evidence (before) | owner | status |
|---|---|---|---|---|---|---|
| BUG-009 (issue A) | P1 | Streets are empty: one road plane, no sidewalks, curbs, crosswalks or street props. Box crates and cube trees are GDScript primitives | teleport `downtown`, drop to street level, look around | `qa/evidence/perf_sweep/00_downtown.png` (rooftop view); after: `street_bot` | Back/Front | open |
| BUG-010 (issue B) | P1 | Park is a flat lawn with cube trees, not a park, and traffic is not routed around it. Old `PARK_RECT` = Rect2(-200, 135, 400, 210) (world.gd:15) | `teleport_point(&"park")` puts the player at the rect centre, y=3 (world.gd:113) | `qa/evidence/perf_sweep/01_park.png`; after: `park_bot` (aerial + 3 ground views, cars_in_park) | Back/Front | open |
| BUG-011 (issue C) | P1 | A defeated enemy plays its fall, then snaps back to the standing rest pose and hangs there until it is freed after 6 s | `--qa=animation_gallery`, clip `death`, or knock out any thug | `qa/evidence/animation_gallery/16_death.png`. Code: humanoid_visual.gd `_process()` calls `skeleton.reset_bone_poses()` once playback stops; enemy.gd:218-227 `_die()` keeps the upright capsule (only `collision_layer = 0`) and calls `queue_free` after 6 s. After: `ko_bot` | Front (visual), Back (enemy.gd) | open |
