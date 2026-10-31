# Halloween Tileset (80+ tiles)

Source: "Halloween Tileset 80+ Tiles.zip" (the original zip is kept in this folder; it can be moved out of the repo or ignored).
Extracted files, renamed:

- `halloween_tileset.png` - 320x352 atlas, 16x16 cells (original: `Haloween Tileset.png`)
- `halloween_preview.png` - artist preview scene (original: `Preview.png`)

WARNING: license file not included in the package - check before publishing.

## Generated files

- `halloween_tileset.tres` - TileSet (physics layer "world" = layer 1, terrain set "Halloween Ground").
  Regenerate: `godot --headless --script res://tools/generate_tileset.gd`
- `levels/main_level.tscn`: "Ground" (TileMapLayer) and "Props" (y-sorted Node2D) are static data written by
  `godot --headless --script res://tools/generate_level_tiles.gd` (seeded; edit the script and rerun to change the layout;
  re-running replaces the "Ground" and "Props" nodes). Run `godot --headless --import` first if new scripts were added.
- `levels/props/prop.tscn` + `prop.gd` (`Prop`, pick a `kind`; `solid` toggles the base collider) and
  `levels/props/spawn_check.gd` (`SpawnCheck`, point query on the world layer used by the spawners).

## Atlas map (cell coordinates)

- Orange grass base: 6x4 cells at (0,0). Blue base: plain cells at (6,2); dark blotches at (6,0), (8,0), (2,4).
- Grass patch pieces (32x32 blocks = 2x2 cells, fringe faces the blue ground; arranged "inverted" around the blue cross):
  TL (14,8), T (12,8), TR (10,8), L (16,2), R (8,2), BL (14,0), B (12,0), BR (10,0).
  The art has no inner-corner pieces, so patches are rectangles built from blocks
  (the generator composes them; the terrain set only supports rectangular painting).
- Stone path: center block (6,4), end caps L (4,4), R (8,4), T (6,2), B (6,6).
- Big dark stain: 6x6 cells at (10,2). Cracked ground: 4x4 cells at (16,4).
- Objects (pixel regions, see `levels/props/prop.gd`): fence, graves, candles, pumpkins, lamp post, arches, bench, log, trees, bushes, leaves.
