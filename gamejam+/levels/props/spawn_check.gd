class_name SpawnCheck
extends RefCounted
## Free-point check against solid collisions (tall and low) for spawners.

const CLEARANCE: float = 8.0
# Default free radius for enemy spawns (EnemyBase.spawn_clearance)
const ENEMY_CLEARANCE: float = 12.0
# Extra tries a spawner gets per unit of clearance above the default (bigger circles fail more often)
const ATTEMPTS_PER_EXTRA_PX: float = 0.5


## Spawn clearance set in an enemy scene (reads the scene's own overrides without instancing it).
static func clearance_of(scene: PackedScene) -> float:
	if scene == null:
		return ENEMY_CLEARANCE
	var state: SceneState = scene.get_state()
	for i: int in state.get_node_property_count(0):
		if state.get_node_property_name(0, i) == &"spawn_clearance":
			return float(state.get_node_property_value(0, i))
	return ENEMY_CLEARANCE


## How many random tries a spawner should make for the given clearance.
static func attempts_for(base_attempts: int, clearance: float) -> int:
	return base_attempts + ceili(maxf(clearance - ENEMY_CLEARANCE, 0.0) * ATTEMPTS_PER_EXTRA_PX)


## Returns true if a circle of "radius" around the point touches no solid obstacle (world and low_obstacle layers).
## The point is the ground (feet), same as the small collider of the player and enemies.
static func is_free(context: Node2D, point: Vector2, radius: float = CLEARANCE) -> bool:
	var space: PhysicsDirectSpaceState2D = context.get_world_2d().direct_space_state
	var shape: CircleShape2D = CircleShape2D.new()
	shape.radius = radius
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, point)
	query.collision_mask = PhysicsLayers.MOVE_MASK
	query.collide_with_bodies = true
	query.collide_with_areas = false
	return space.intersect_shape(query, 1).is_empty()
