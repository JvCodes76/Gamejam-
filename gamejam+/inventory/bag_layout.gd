class_name BagLayout
extends RefCounted

# Bag local coordinates: origin at the center, y down. Traced from the CraftingItemBag sprite (64x64 at 4x,
# centered at SPRITE_OFFSET), 2 sprite px inside its outline; the top edge, below the drawstring, is the mouth.
# Same area as the old placeholder bag (~33.8k px²), so the capacity does not change.
const INTERIOR: PackedVector2Array = [
	Vector2(-66, -106), Vector2(62, -106),
	Vector2(70, -46), Vector2(86, -10),
	Vector2(90, 46), Vector2(90, 78),
	Vector2(82, 98), Vector2(70, 106),
	Vector2(-82, 106), Vector2(-90, 82),
	Vector2(-90, 38), Vector2(-78, 10),
	Vector2(-78, -54), Vector2(-66, -70),
]
# Bag mouth: the whole top edge
const MOUTH_RECT: Rect2 = Rect2(-66, -122, 128, 16)
const WALL_THICKNESS: float = 16.0
# Sprite scale and center (local px) the INTERIOR was traced with
const SPRITE_SCALE: float = 4.0
const SPRITE_OFFSET: Vector2 = Vector2(14, -14)
