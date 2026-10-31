class_name CauldronLayout
extends RefCounted

# Caldeirão largo (~143x103), coordenadas locais: origem no centro, y para baixo
const INTERIOR: PackedVector2Array = [
	Vector2(-47, -52), Vector2(47, -52),
	Vector2(64, -30), Vector2(71, 0),
	Vector2(64, 32), Vector2(43, 52),
	Vector2(-43, 52), Vector2(-64, 32),
	Vector2(-71, 0), Vector2(-64, -30),
]
# Boca no topo (94 px)
const MOUTH_RECT: Rect2 = Rect2(-47, -68, 94, 16)
const WALL_THICKNESS: float = 16.0


# Interior escalado pelo multiplicador de tamanho
static func scaled_interior(multiplier: float) -> PackedVector2Array:
	return Transform2D().scaled(Vector2(multiplier, multiplier)) * INTERIOR


# Boca escalada pelo multiplicador (a altura da boca não muda)
static func scaled_mouth(multiplier: float) -> Rect2:
	var interior_top: float = INTERIOR[0].y * multiplier
	var width: float = MOUTH_RECT.size.x * multiplier
	return Rect2(-width * 0.5, interior_top - MOUTH_RECT.size.y, width, MOUTH_RECT.size.y)
