# QA harness

`qa/qa_runner.gd` is the `QA` autoload. It is inert (no output, no processing) unless a user arg `--qa=<scenario>` is passed.

```powershell
$G = "<path to>\Godot_v4.7.2-stable_win64_console.exe"
& $G --path . --quit-after 900 -- --qa=smoke *> qa\evidence\smoke.log   # run from the project folder
echo $LASTEXITCODE          # 0 pass, 1 fail
python qa\tools\check_log.py qa\evidence\smoke.log   # 1 if ERROR/WARNING/Parser Error/Invalid access
```

All scenarios: `powershell -ExecutionPolicy Bypass -File qa/tools/run_all.ps1` (logs in `qa/evidence/_logs/`).
Screenshots need a rendering window; do not use `--headless` for evidence runs (screenshots are skipped there).
Raise `--quit-after` for long scenarios (see run_all.ps1).

| scenario | what | pass criteria |
|---|---|---|
| smoke | boot, player/world found, spawn screenshot | player exists, y > -50 |
| load_all | loads every .gd/.tscn under res:// | no load/compile failures |
| traversal_bot | forward + hold swing, release at arc top | swings ≥ 20, 1 km in ≤ 45 s, max_stuck_s < 2, min_y > -50 |
| city_flythrough | 180 s random turns | no stuck > 2 s (P1), no y < -50 (P0) |
| combat_bot | teleport to base, 3 thugs, attack/dodge 30 s | hits ≥ 5, max_combo ≥ 5 |
| animation_gallery | hero.tscn alone, play() every contract clip | play() exists; missing clips logged as P2 |
| perf_sweep | spawn, swinging, every teleport point | avg_fps ≥ 60, 1% low ≥ 40 |
| regression | start, 60 s flying, 15 s fight, exit | swings ≥ 5, hits ≥ 3, not stuck |
| soak10 | 10 min random route | no stuck, no fall, static memory growth ≤ 25 % |

## metrics.json (common fields)
`scenario, pass, failures[], bugs[{severity,text}], duration_s, started_at, godot_version, avg_fps, screenshots[]`
plus scenario keys; swing scenarios add `swings, distance_m, time_to_target_s, max_stuck_s, min_y, max_speed, avg_speed, max_chain`; perf adds `low1_fps, draw_calls, static_mem_mb, video_mem_mb, sections`.

## Dependencies on other roles
Player in group `player` with `set_bot_input(move, actions)` (actions keys = input action names: `swing`, `jump`, `attack`, `dodge`), `get_state()`, `get_velocity_world()`, `teleport()`, `unstuck()`; `Events.web_attached` emitted once per attach; World with `teleport_point()` / `spawn_enemies()`; enemies in group `enemy`.

Self-test of the log checker: `python qa/tools/selftest_check_log.py`.
