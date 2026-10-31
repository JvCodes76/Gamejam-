class_name BagLayout
extends RefCounted

# Bolsa 1.3x maior (area ~1.7x) para acomodar itens 3x (48 px); boca 92 px
# Coordenadas locais da bolsa: origem no centro, y para baixo
const INTERIOR: PackedVector2Array = [
	Vector2(-72, -104), Vector2(72, -104),
	Vector2(86, -52), Vector2(91, 13),
	Vector2(83, 65), Vector2(57, 99),
	Vector2(-57, 99), Vector2(-83, 65),
	Vector2(-91, 13), Vector2(-86, -52),
]
# Boca da bolsa no topo
const MOUTH_RECT: Rect2 = Rect2(-46, -120, 92, 16)
const WALL_THICKNESS: float = 16.0
