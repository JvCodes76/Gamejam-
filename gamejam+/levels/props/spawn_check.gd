class_name SpawnCheck
extends RefCounted
## Free-point check against solid collisions (tall and low) for spawners.

const CLEARANCE: float = 8.0


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
