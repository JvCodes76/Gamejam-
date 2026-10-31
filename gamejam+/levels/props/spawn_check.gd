class_name SpawnCheck
extends RefCounted
## Checagem de ponto livre de colisoes solidas (layer world) para spawners.

const WORLD_MASK: int = 1
const CLEARANCE: float = 8.0


## Retorna true se o ponto (e uma folga ao redor) nao esta dentro de um corpo solido do mundo.
static func is_free(context: Node2D, point: Vector2) -> bool:
	var space: PhysicsDirectSpaceState2D = context.get_world_2d().direct_space_state
	var query: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
	query.collision_mask = WORLD_MASK
	for offset: Vector2 in [Vector2.ZERO, Vector2.LEFT * CLEARANCE, Vector2.RIGHT * CLEARANCE, Vector2.UP * CLEARANCE, Vector2.DOWN * CLEARANCE]:
		query.position = point + offset
		if not space.intersect_point(query, 1).is_empty():
			return false
	return true
