# Mechanics checklist (draft, QA)

Run: `Godot_v4.7.2-stable_win64_console.exe --path . -- --qa=<name>` → `qa/evidence/<name>/metrics.json`.

| Mechanic (README / data) | Scenario | Manual check |
|---|---|---|
| WASD move, mouse look | smoke, traversal_bot | Walk on a roof, rotate camera with mouse |
| Shift swing | traversal_bot, city_flythrough, soak10 | Hold Shift in the air: web attaches, arc, release at top |
| Shift sprint (ground) | — | Hold Shift + W on the ground: speed rises |
| Shift wall run | — | Swing into a building with Shift held: runs up the wall |
| Space jump | traversal_bot (drive_swing kicks off with jump) | Space on the ground |
| Point Launch (Space near zip end) | — | Q to a point, press Space near arrival: slowmo + launch |
| Q Web Zip | — | Aim at a ledge, Q: player zips to zip_point |
| Ctrl dodge / cancel attack | combat_bot (dodge on spider_sense) | Ctrl during an enemy wind-up: perfect dodge slowmo |
| Ctrl hold in air: dive | — | Hold Ctrl while falling: faster descent |
| LMB attack, combo | combat_bot, damage_bot | Hit thugs 5×: combo label ≥ 5 |
| F finisher (3 Focus) | — | Fill 3 Focus segments, press F next to enemy |
| H heal | — | Take damage, H with Focus: HP rises |
| C air trick | — | Press C in the air: trick anim, Focus gain |
| Esc pause | — | Esc stops the game, Esc resumes |
| F1 hide HUD | — | F1 toggles HUD |
| F3 debug menu (time, teleports, unstuck, invincible, +XP, spawn thugs) | — | Open F3, use every button once |
| HUD: HealthBar, 3 FocusSegments, GadgetPanel, ComboLabel | smoke (screenshots) | Visible in normal play |
| Gadgets (5: web_bomb, impact_web, trip_mine, electric_web, suspension_matrix), G use, Tab next | gadget_bot, stealth_bot, menu_bot (Tab) | Tab cycles wheel highlight, G fires each gadget |
| Skills (≥12, skills.json), K menu | progression_bot, damage_bot, menu_bot (K) | K opens SKILLS, unlock one with points |
| attack_damage effect on damage | damage_bot (damage_level0 < damage_level1) | Compare hit numbers before/after skill |
| Suits (classic, stealth, iron), L menu, colours | progression_bot, menu_bot (L, Suit_Primary colour) | L, pick suit: hero colour changes on screen |
| Map, M | menu_bot (M) | M opens map, M closes |
| Save progress (user://progress.json; QA: progress_qa.json) | progression_bot | Unlock skill, restart, still unlocked |
| Enemy archetypes (thug, brute, gunner, shield, sniper) | combat_bot, base_waves | F3 spawn, fight each type |
| Enemy bases: alarm, 3 waves, base_cleared XP | base_waves | Approach base, trigger alarm, clear waves |
| Stealth radius / undetected approach | stealth_bot | Approach base slowly: no alarm |
| City grid, buildings, time of day | city_flythrough, perf_sweep, load_all | Fly over city, change time in F3 |
| Chunk streaming (≤25 loaded of > 25) | world_stream_bot | Fly away: far buildings hide, come back: same place |
| Traffic cars, stop 6 m before player | world_stream_bot (count > 0) | Stand on a lane: car stops, step off: it goes |
| Animations (17 clips) | animation_gallery | — |
| Stability / perf | soak10, perf_sweep, regression | — |
