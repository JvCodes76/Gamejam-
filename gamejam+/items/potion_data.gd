class_name PotionData
extends Resource

# Items used in the potion
var items: Array[ItemData] = []
# Liquid color: average of the item colors weighted by area*scale²
var color: Color = Color.WHITE
# Sum of the item hull areas (px², at each item's scale)
var volume: float = 0.0
# EffectType -> float, already including synergies and aspect bonuses
var effect_totals: Dictionary = {}
# Aspect -> int
var aspect_counts: Dictionary = {}
# Ids of the active special recipes (SpecialSynergies)
var special_synergies: Array[StringName] = []


# Builds the potion; scales[i] is the scale of item i (same size as items)
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
	potion.special_synergies = SpecialSynergies.find_ids(new_items)
	if not potion.special_synergies.is_empty():
		print("[Synergy] - special recipes in the potion: %s" % ", ".join(potion.special_synergies))
	print("[Items] - Potion: %d items, volume %.1f" % [new_items.size(), total])
	return potion


# Area of a polygon (shoelace formula)
static func _polygon_area(poly: PackedVector2Array) -> float:
	var sum: float = 0.0
	for i: int in poly.size():
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[(i + 1) % poly.size()]
		sum += a.x * b.y - b.x * a.y
	return sum * 0.5
