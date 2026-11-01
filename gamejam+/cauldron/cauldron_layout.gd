class_name CauldronLayout
extends RefCounted

# Wide cauldron (~143x103), local coordinates: origin at the center, y down
const INTERIOR: PackedVector2Array = [
	Vector2(-47, -52), Vector2(47, -52),
	Vector2(64, -30), Vector2(71, 0),
	Vector2(64, 32), Vector2(43, 52),
	Vector2(-43, 52), Vector2(-64, 32),
	Vector2(-71, 0), Vector2(-64, -30),
]
# Mouth at the top (94 px)
const MOUTH_RECT: Rect2 = Rect2(-47, -68, 94, 16)
const WALL_THICKNESS: float = 16.0


# Interior scaled by the size multiplier
static func scaled_interior(multiplier: float) -> PackedVector2Array:
	return Transform2D().scaled(Vector2(multiplier, multiplier)) * INTERIOR


# Mouth scaled by the multiplier (the mouth height does not change)
static func scaled_mouth(multiplier: float) -> Rect2:
	var interior_top: float = INTERIOR[0].y * multiplier
	var width: float = MOUTH_RECT.size.x * multiplier
	return Rect2(-width * 0.5, interior_top - MOUTH_RECT.size.y, width, MOUTH_RECT.size.y)
