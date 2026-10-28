# Decisions

- Main scene builds the World, Player and HUD from code (`scripts/core/main.gd`), which keeps the `.tscn` files small and the ownership boundaries clear.
- Hero and enemies use the procedural capsule fallback in `HumanoidVisual` until Front's `hero.glb` and `enemy.glb` exist. The colours already follow the brief: red and blue suit, white emblem, white lenses.
- Swing anchors must lie ahead of the hero (dot > 0.25). When the cone rays miss, a side-wall fallback anchor keeps swing chains alive in a street.
- Airborne wall runs start only on near head-on impacts (dot > 0.75), so glancing contacts don't pull the hero off the avenue.
- The camera stops auto-following travel direction in QA bot mode, so the bot's "forward" stays along the avenue.
