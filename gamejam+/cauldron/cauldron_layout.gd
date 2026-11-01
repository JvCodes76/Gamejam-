class_name CauldronLayout
extends RefCounted

# Local coordinates: origin at the center, y down. Traced from the bowl of the CraftingCauldron sprite (48x32 at
# SPRITE_SCALE, centered at the origin), 1 sprite px inside its outline: the mouth is the neck under the rim,
# the sides follow the belly (handles and legs stay outside).
const INTERIOR: PackedVector2Array = [
	Vector2(-66, -72), Vector2(66, -72),
	Vector2(66, -36), Vector2(77, -22),
	Vector2(82, -12), Vector2(82, 12),
	Vector2(72, 22), Vector2(66, 36),
	Vector2(55, 50), Vector2(50, 61),
	Vector2(-50, 61), Vector2(-55, 50),
	Vector2(-66, 36), Vector2(-72, 22),
	Vector2(-82, 12), Vector2(-82, -12),
	Vector2(-77, -22), Vector2(-66, -36),
]
# Mouth at the top (the whole neck, 132 px)
const MOUTH_RECT: Rect2 = Rect2(-66, -88, 132, 16)
# Sprite scale (at size multiplier 1) the INTERIOR was traced with
const SPRITE_SCALE: float = 5.5
const WALL_THICKNESS: float = 16.0


# Interior scaled by the size multiplier
static func scaled_interior(multiplier: float) -> PackedVector2Array:
	return Transform2D().scaled(Vector2(multiplier, multiplier)) * INTERIOR


# Mouth scaled by the multiplier (the mouth height does not change)
static func scaled_mouth(multiplier: float) -> Rect2:
	var interior_top: float = INTERIOR[0].y * multiplier
	var width: float = MOUTH_RECT.size.x * multiplier
	return Rect2(-width * 0.5, interior_top - MOUTH_RECT.size.y, width, MOUTH_RECT.size.y)
