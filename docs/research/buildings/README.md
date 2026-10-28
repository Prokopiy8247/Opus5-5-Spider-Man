# NY facade research notes (iteration 3, Front)

Sources (fetch these again before quoting; this worker could not browse):
- NYC LPC "Rowhouse Manual": https://www.nyc.gov/assets/lpc/downloads/pdf/pubs/rowhouse_manual.pdf
- Brick bonds (running / Flemish / common bond): https://en.wikipedia.org/wiki/Brickwork
- Art Deco in NYC: https://en.wikipedia.org/wiki/Art_Deco_architecture_of_New_York_City
- Curtain walls: https://en.wikipedia.org/wiki/Curtain_wall_(architecture)
- Brutalism / board-formed concrete: https://en.wikipedia.org/wiki/Brutalist_architecture
- Terracotta in NYC: https://en.wikipedia.org/wiki/Architectural_terracotta
- Marvel's Spider-Man city analysis (GDC 2019, "Marvel's Spider-Man: A Technical Postmortem"): https://www.gdcvault.com/

## Real-world measurements used in the bake
| Item | Value |
|---|---|
| US modular brick | 194 x 57 mm face + 10 mm joint, so 3 courses = 203 mm (about 15 courses per metre) |
| Common bond | header course every 6th course (tenements, warehouses) |
| Limestone ashlar | blocks about 0.6 x 1.2 m, 6 mm joints |
| Board-formed concrete | boards 100-150 mm, tie holes on a 0.6 x 0.6 m grid |
| Curtain wall | mullions 1.5 m, spandrel at each slab, 50-75 mm caps |
| Window | 1.2 x 1.8 m, reveal 100-200 mm in masonry, stone sill projecting 40 mm |
| Storefront | 4-5 m tall, sign band 0.6-0.9 m, bulkhead 0.45 m |

## How the original game reads on screen
- Facades read from **window rhythm** and **deep reveals**: dark AO in the recess matters more than wall micro detail.
- Each block mixes 3-5 materials, and ground floors always differ (shops, awnings, shutters).
- At distance towers turn into flat colour with sky reflection, and the window grid does not shimmer.
- At night the interiors vary: warm/cool, blinds, many dark windows, never pure white.

These notes drive `assets/blender/models/building_textures.py`: we exaggerate reveal AO, add sills/lintels per style and include curtain masks for the night look.
