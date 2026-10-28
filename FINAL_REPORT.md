# Final report: Web Slinger (Godot 4.7.2)

## Result
Playable open-world swinging game: 3000x1500 m procedural city with streaming and traffic, web swing / zip / wall run, combo combat, 5 gadgets, 15-skill tree, 3 suits, 5 enemy archetypes, 5 enemy bases with stealth and 3 waves, Blender-built hero/enemy models with 17 clips, menus K/L/M, gadget wheel (Tab), save/load.

## Verification
`powershell -ExecutionPolicy Bypass -File qa/tools/run_all.ps1`: **16/16 PASS**, every log clean (no ERROR/WARNING), including 10-minute soak10.

| Check | Evidence |
|---|---|
| Streaming: loaded <= 25, total 323 chunks, player chunk loaded at each of 9 steps | world_stream_bot |
| Traffic: 40 cars active throughout | world_stream_bot |
| Menus K/L/M open and pause, Tab moves wheel 0 -> 1, suit primary colour changes | menu_bot |
| attack_damage: modifier 1.0 -> 1.25, first-hit damage 10.0 -> 12.5 | damage_bot |
| Performance after streaming + traffic: avg 419 FPS, 1% low 157, max 847 draw calls (RTX 5070) | perf_sweep |
| Bases keep running (stream_always), waves and clear | base_waves, stealth_bot, regression 8/8 |

Mechanic-to-test mapping: docs/MECHANICS_CHECKLIST.md. Bugs: docs/BUGS.md (BUG-001..008 verified).

## Known limitations
- Car stopping before the player is covered by the Python model (`scripts/world/traffic/sim_traffic.py`) only, not by an in-engine scenario.
- Building reappearance is checked through chunk counts and is_chunk_loaded, not by pixel comparison.
- Screenshots were produced but not reviewed visually by the agent.
- Perf dropped from 620 to 419 avg FPS after adding traffic and 128 m mesh chunks (more draw calls).
- Work is not committed; `.sharrowkin/` must be removed from the git index (`git rm -r --cached .sharrowkin`).
