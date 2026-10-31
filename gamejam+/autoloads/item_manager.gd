extends Node

const SYNERGIES_DIR: String = "res://items/synergies/"
const ASPECT_BONUSES_DIR: String = "res://items/aspect_bonuses/"

# Itens possuídos (não contam para efeitos)
var owned_items: Array[ItemData] = []
# Itens usados no caldeirão (únicos que contam)
var brewed_items: Array[ItemData] = []
var synergies: Array[ItemSynergy] = []
var aspect_bonuses: Array[AspectBonus] = []

# Itens na bolsa: {"item", "position", "rotation", "scale"}
var bag_entries: Array[Dictionary] = []
# Itens no chão: {"item": ItemData, "position": Vector2 mundo}
var ground_entries: Array[Dictionary] = []
var starting_items_seeded: bool = false
# Itens aguardando no chão da tela de inventário (bolsa cheia)
var pending_items: Array[ItemData] = []
# True enquanto a tela de inventário está aberta
var inventory_open: bool = false
var shrink_upgrade_active: bool = false
var shrink_scale: float = 0.6
# Escala base dos sprites na tela de inventário (16 px -> 48 px)
var base_item_scale: float = 3.0


func _ready() -> void:
	synergies.assign(_load_resources(SYNERGIES_DIR))
	aspect_bonuses.assign(_load_resources(ASPECT_BONUSES_DIR))
	print("[Items] - %d sinergias, %d bônus de aspecto carregados" % [synergies.size(), aspect_bonuses.size()])


# Adiciona um item ao inventário
func add_item(item: ItemData) -> void:
	if item == null or not item.is_valid():
		return
	if _contains(owned_items, item):
		return
	owned_items.append(item)
	print("[Items] - Item possuído: %s" % item.id)


# Usa o item no caldeirão; passa a contar para efeitos
func brew_item(item: ItemData) -> void:
	if item == null or not item.is_valid():
		return
	if not _contains(owned_items, item):
		owned_items.append(item)
	if _contains(brewed_items, item):
		push_warning("[Items] - Item já brewed: %s" % item.id)
		return
	brewed_items.append(item)
	print("[Items] - Item brewed: %s" % item.id)
	EventBus.item_brewed.emit(item.id)
	EventBus.active_effects_changed.emit()


func is_brewed(item: ItemData) -> bool:
	return _contains(brewed_items, item)


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
	bag_entries.clear()
	ground_entries.clear()
	starting_items_seeded = false
	shrink_upgrade_active = false
	EventBus.active_effects_changed.emit()


# Escala atual dos itens (reduzida se o upgrade estiver ativo)
func current_item_scale() -> float:
	return base_item_scale * (shrink_scale if shrink_upgrade_active else 1.0)


# Guarda o item na bolsa se couber facilmente
func try_auto_store(item: ItemData) -> bool:
	var scale_now: float = current_item_scale()
	var spot: Variant = BagFit.find_free_position(item, bag_entries, scale_now)
	if spot == null:
		print("[Inventory] - Sem espaço na bolsa: %s" % (item.id if item != null else &"null"))
		return false
	bag_entries.append({"item": item, "position": spot["position"], "rotation": spot["rotation"], "scale": scale_now})
	add_item(item)
	print("[Inventory] - Item guardado na bolsa: %s" % item.id)
	return true


# Substitui o layout da bolsa
func save_bag_layout(entries: Array[Dictionary]) -> void:
	bag_entries = entries.duplicate()


func remove_from_bag(entry: Dictionary) -> void:
	bag_entries.erase(entry)


# Solta o item no chão do mundo
func drop_to_ground(item: ItemData, world_position: Vector2) -> void:
	ground_entries.append({"item": item, "position": world_position})
	EventBus.ground_items_changed.emit()


func take_from_ground(entry: Dictionary) -> void:
	ground_entries.erase(entry)
	EventBus.ground_items_changed.emit()


func _is_synergy_active(synergy: ItemSynergy) -> bool:
	if synergy.required_items.is_empty():
		return false
	for req: ItemData in synergy.required_items:
		if not _contains(brewed_items, req):
			return false
	return true


# Compara por id, já que o mesmo .tres pode ser carregado como instâncias distintas
func _contains(list: Array[ItemData], item: ItemData) -> bool:
	for other: ItemData in list:
		if other == item or other.id == item.id:
			return true
	return false


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
