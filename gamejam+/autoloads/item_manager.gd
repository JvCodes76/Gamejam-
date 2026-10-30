extends Node

const SYNERGIES_DIR: String = "res://items/synergies/"
const ASPECT_BONUSES_DIR: String = "res://items/aspect_bonuses/"

# Itens possuídos (não contam para efeitos)
var owned_items: Array[ItemData] = []
# Itens usados no caldeirão (únicos que contam)
var brewed_items: Array[ItemData] = []
var synergies: Array[ItemSynergy] = []
var aspect_bonuses: Array[AspectBonus] = []


func _ready() -> void:
	synergies.assign(_load_resources(SYNERGIES_DIR))
	aspect_bonuses.assign(_load_resources(ASPECT_BONUSES_DIR))
	print("[Items] - %d sinergias, %d bônus de aspecto carregados" % [synergies.size(), aspect_bonuses.size()])


# Adiciona um item ao inventário
func add_item(item: ItemData) -> void:
	if item == null or not item.is_valid():
		return
	owned_items.append(item)
	print("[Items] - Item possuído: %s" % item.id)


# Usa o item no caldeirão; passa a contar para efeitos
func brew_item(item: ItemData) -> void:
	if item == null or not item.is_valid():
		return
	if not owned_items.has(item):
		owned_items.append(item)
	if brewed_items.has(item):
		push_warning("[Items] - Item já brewed: %s" % item.id)
		return
	brewed_items.append(item)
	print("[Items] - Item brewed: %s" % item.id)
	EventBus.item_brewed.emit(item.id)
	EventBus.active_effects_changed.emit()


func is_brewed(item: ItemData) -> bool:
	return brewed_items.has(item)


# Conta aspectos apenas dos itens brewed
func get_aspect_count(aspect: ItemEnums.Aspect) -> int:
	var count: int = 0
	for item: ItemData in brewed_items:
		for a: ItemEnums.Aspect in item.aspects:
			if a == aspect:
				count += 1
	return count


# Agrega efeitos de itens brewed, sinergias e bônus de aspecto
func get_active_effects() -> Array[ItemEffect]:
	var result: Array[ItemEffect] = []
	for item: ItemData in brewed_items:
		result.append_array(item.effects)
	for synergy: ItemSynergy in synergies:
		if _is_synergy_active(synergy):
			result.append_array(synergy.bonus_effects)
	for bonus: AspectBonus in aspect_bonuses:
		if get_aspect_count(bonus.aspect) >= bonus.required_count:
			result.append_array(bonus.bonus_effects)
	return result


# Soma as magnitudes por tipo de efeito
func get_effect_totals() -> Dictionary[ItemEffect.EffectType, float]:
	var totals: Dictionary[ItemEffect.EffectType, float] = {}
	for effect: ItemEffect in get_active_effects():
		totals[effect.effect_type] = totals.get(effect.effect_type, 0.0) + effect.magnitude
	return totals


# Limpa o estado para nova partida
func reset() -> void:
	owned_items.clear()
	brewed_items.clear()
	EventBus.active_effects_changed.emit()


func _is_synergy_active(synergy: ItemSynergy) -> bool:
	if synergy.required_items.is_empty():
		return false
	for req: ItemData in synergy.required_items:
		if not brewed_items.has(req):
			return false
	return true


func _load_resources(dir_path: String) -> Array:
	var out: Array = []
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	for file: String in dir.get_files():
		# Em export, arquivos podem ter sufixo .remap
		var clean: String = file.trim_suffix(".remap")
		if clean.ends_with(".tres"):
			var res: Resource = load(dir_path + clean)
			if res != null:
				out.append(res)
	return out
