class_name BagLayout
extends RefCounted

# Coordenadas locais da bolsa: origem no centro, y para baixo
const INTERIOR: PackedVector2Array = [
	Vector2(-55, -80), Vector2(55, -80),
	Vector2(66, -40), Vector2(70, 10),
	Vector2(64, 50), Vector2(44, 76),
	Vector2(-44, 76), Vector2(-64, 50),
	Vector2(-70, 10), Vector2(-66, -40),
]
# Boca da bolsa no topo
const MOUTH_RECT: Rect2 = Rect2(-35, -92, 70, 12)
const WALL_THICKNESS: float = 8.0
