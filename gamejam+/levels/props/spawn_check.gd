class_name SpawnCheck
extends RefCounted
## Checagem de ponto livre de colisoes solidas (altas e baixas) para spawners.

const CLEARANCE: float = 8.0


## Retorna true se um circulo de "radius" em torno do ponto nao toca nenhum obstaculo solido (layers world e low_obstacle).
## O ponto e o chao (pes), igual ao colisor pequeno de player e inimigos.
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
