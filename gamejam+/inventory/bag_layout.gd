class_name BagLayout
extends RefCounted

# Bag 1.3x larger (area ~1.7x) to fit 3x items (48 px); mouth 92 px
# Bag local coordinates: origin at the center, y down
const INTERIOR: PackedVector2Array = [
	Vector2(-72, -104), Vector2(72, -104),
	Vector2(86, -52), Vector2(91, 13),
	Vector2(83, 65), Vector2(57, 99),
	Vector2(-57, 99), Vector2(-83, 65),
	Vector2(-91, 13), Vector2(-86, -52),
]
# Bag mouth at the top
const MOUTH_RECT: Rect2 = Rect2(-46, -120, 92, 16)
const WALL_THICKNESS: float = 16.0
