class_name PotionData
extends Resource

# Itens usados na poção
var items: Array[ItemData] = []
# Cor do líquido: média das cores dos itens ponderada por área*escala²
var color: Color = Color.WHITE
# Soma das áreas dos hulls dos itens (px², na escala de cada item)
var volume: float = 0.0
# EffectType -> float, já com sinergias e bônus de aspecto
var effect_totals: Dictionary = {}
# Aspect -> int
var aspect_counts: Dictionary = {}


# Monta a poção; scales[i] é a escala do item i (mesmo tamanho de items)
static func from_items(new_items: Array[ItemData], scales: Array[float]) -> PotionData:
	var potion: PotionData = PotionData.new()
	potion.items = new_items.duplicate()
	var weighted: Color = Color(0, 0, 0, 0)
	var total: float = 0.0
	for i: int in new_items.size():
		var item: ItemData = new_items[i]
		var item_scale: float = scales[i] if i < scales.size() else 1.0
		var area: float = absf(_polygon_area(ColliderBuilder.build_hull(item.icon, item_scale)))
		total += area
		weighted += Color(item.color.r * area, item.color.g * area, item.color.b * area, area)
	potion.volume = total
	if total > 0.0:
		potion.color = Color(weighted.r / total, weighted.g / total, weighted.b / total, 1.0)
	potion.effect_totals = ItemManager.compute_effect_totals(new_items)
	potion.aspect_counts = ItemManager.count_aspects(new_items)
	print("[Items] - Poção: %d itens, volume %.1f" % [new_items.size(), total])
	return potion


# Área de um polígono (fórmula do cadarço)
static func _polygon_area(poly: PackedVector2Array) -> float:
	var sum: float = 0.0
	for i: int in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5
