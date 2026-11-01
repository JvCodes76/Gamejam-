class_name ColliderBuilder
extends RefCounted

# Polygon cache at scale 1.0, keyed by texture
static var _cache: Dictionary = {}


# Generates outline (alpha) polygons centered on the origin, in pixels
static func build_polygons(texture: Texture2D, scale: float = 1.0, epsilon: float = 1.0) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	if texture == null:
		return result
	var key: String = "%s|%s|%s" % [texture.resource_path, texture.get_instance_id(), epsilon]
	if not _cache.has(key):
		_cache[key] = _compute(texture, epsilon)
	var base: Array = _cache[key]
	for poly: PackedVector2Array in base:
		if is_equal_approx(scale, 1.0):
			result.append(poly)
		else:
			result.append(Transform2D().scaled(Vector2(scale, scale)) * poly)
	return result


# Convex hull of all polygons, for fast fit tests
static func build_hull(texture: Texture2D, scale: float = 1.0) -> PackedVector2Array:
	var all_points: PackedVector2Array = PackedVector2Array()
	for poly: PackedVector2Array in build_polygons(texture, scale):
		all_points.append_array(poly)
	if all_points.size() < 3:
		return PackedVector2Array()
	var hull: PackedVector2Array = Geometry2D.convex_hull(all_points)
	# convex_hull closes the loop by repeating the first point
	if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
		hull.remove_at(hull.size() - 1)
	return hull


static func _compute(texture: Texture2D, epsilon: float) -> Array[PackedVector2Array]:
	var out: Array[PackedVector2Array] = []
	var image: Image = texture.get_image()
	if image == null:
		push_warning("[Inventory] - Texture without image: %s" % texture.resource_path)
		return out
	if image.is_compressed():
		image.decompress()
	var size: Vector2i = image.get_size()
	var bitmap: BitMap = BitMap.new()
	bitmap.create_from_image_alpha(image)
	var offset: Vector2 = Vector2(size) * 0.5
	for poly: PackedVector2Array in bitmap.opaque_to_polygons(Rect2i(Vector2i.ZERO, size), epsilon):
		if poly.size() < 3:
			continue
		var shifted: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in poly:
			shifted.append(p - offset)
		out.append(shifted)
	return out
