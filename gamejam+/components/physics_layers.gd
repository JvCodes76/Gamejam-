class_name PhysicsLayers
extends RefCounted
## 2D physics layers (bitmask values) and composite masks, in a single place.
## Tall (tree, wall, post, arch, arena walls): WORLD (blocks movement and projectiles).
## Low (tombstone, bench, bush, log, cauldron): LOW_OBSTACLE (movement only; projectiles pass over, except for tombstones).
## BULLET_BLOCKER is the volume (height) of tall obstacles and tombstones: only projectiles see this layer.

const WORLD: int = 1
const PLAYER: int = 2
const ENEMY: int = 4
const PLAYER_BULLET: int = 8
const ENEMY_BULLET: int = 16
const LOW_OBSTACLE: int = 32
const BULLET_BLOCKER: int = 64

# What blocks the movement of the player, enemies and ghosts
const MOVE_MASK: int = WORLD | LOW_OBSTACLE
# What destroys a projectile
const PROJECTILE_WALL_MASK: int = WORLD | BULLET_BLOCKER
