class_name BagFit
extends RefCounted

const GRID_STEP: float = 6.0
const ROTATIONS: Array[float] = [0.0, PI * 0.5, PI, PI * 1.5]


# Procura a primeira posição livre (com margem) dentro da bolsa; null se não couber
static func find_free_position(item: ItemData, entries: Array[Dictionary], shrink_scale: float, margin: float = 3.0) -> Variant:
	if item == null or item.icon == null:
		return null
	var hull: PackedVector2Array = ColliderBuilder.build_hull(item.icon, shrink_scale)
	if hull.size() < 3:
		return null
	# Hulls já ocupados, inflados pela margem
	var occupied: Array[PackedVector2Array] = []
	for e: Dictionary in entries:
		var other: ItemData = e["item"]
		var h: PackedVector2Array = ColliderBuilder.build_hull(other.icon, e["scale"])
		var placed: PackedVector2Array = _transform(h, e["position"], e["rotation"])
		var inflated: Array[PackedVector2Array] = Geometry2D.offset_polygon(placed, margin)
		if not inflated.is_empty():
			occupied.append(inflated[0])
	var bounds: Rect2 = Rect2(BagLayout.INTERIOR[0], Vector2.ZERO)
	for p: Vector2 in BagLayout.INTERIOR:
		bounds = bounds.expand(p)
	var y: float = bounds.end.y
	while y >= bounds.position.y:
		var x: float = bounds.position.x
		while x <= bounds.end.x:
			for rot: float in ROTATIONS:
				var candidate: PackedVector2Array = _transform(hull, Vector2(x, y), rot)
				if _is_valid(candidate, occupied):
					return {"position": Vector2(x, y), "rotation": rot}
			x += GRID_STEP
		y -= GRID_STEP
	return null


static func _is_valid(candidate: PackedVector2Array, occupied: Array[PackedVector2Array]) -> bool:
	# Contido no interior: nada sobra ao subtrair o interior
	if not Geometry2D.clip_polygons(candidate, BagLayout.INTERIOR).is_empty():
		return false
	for other: PackedVector2Array in occupied:
		if not Geometry2D.intersect_polygons(candidate, other).is_empty():
			return false
	return true


static func _transform(poly: PackedVector2Array, pos: Vector2, rot: float) -> PackedVector2Array:
	return Transform2D(rot, pos) * poly
