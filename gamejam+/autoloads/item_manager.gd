extends Node

const SYNERGIES_DIR: String = "res://items/synergies/"
const ASPECT_BONUSES_DIR: String = "res://items/aspect_bonuses/"

# Itens possuídos (só as poções contam para efeitos)
var owned_items: Array[ItemData] = []
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
# Andar atual (1 = primeiro); cada andar encolhe os itens por 1/FLOOR_SHRINK_FACTOR
var floor_level: int = 1
const FLOOR_SHRINK_FACTOR: float = 1.25
# Slots de poção (2) e o índice do ativo
var potion_slots: Array[PotionData] = [null, null]
var active_potion_index: int = 0


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


# Conta aspectos de uma lista de itens
func count_aspects(items: Array[ItemData]) -> Dictionary:
	var counts: Dictionary = {}
	for item: ItemData in items:
		for a: ItemEnums.Aspect in item.aspects:
			counts[a] = int(counts.get(a, 0)) + 1
	return counts


# Efeitos dos itens + sinergias satisfeitas + bônus de aspecto atingidos
func compute_effect_totals(items: Array[ItemData]) -> Dictionary:
	var effects: Array[ItemEffect] = []
	for item: ItemData in items:
		effects.append_array(item.effects)
	for synergy: ItemSynergy in synergies:
		if _is_synergy_active(synergy, items):
			effects.append_array(synergy.bonus_effects)
	var counts: Dictionary = count_aspects(items)
	for bonus: AspectBonus in aspect_bonuses:
		if int(counts.get(bonus.aspect, 0)) >= bonus.required_count:
			effects.append_array(bonus.bonus_effects)
	var totals: Dictionary = {}
	for effect: ItemEffect in effects:
		totals[effect.effect_type] = float(totals.get(effect.effect_type, 0.0)) + effect.magnitude
	return totals


# Poção ativa (null se o slot está vazio)
func get_active_potion() -> PotionData:
	return potion_slots[active_potion_index]


func set_potion_slot(index: int, potion: PotionData) -> void:
	if index < 0 or index >= potion_slots.size():
		return
	potion_slots[index] = potion
	print("[Items] - Slot de poção %d atualizado" % index)
	EventBus.potion_slots_changed.emit()
	if index == active_potion_index:
		EventBus.active_effects_changed.emit()


# Guarda no primeiro slot livre; se cheios, substitui o ativo. Retorna o índice usado
func store_potion(potion: PotionData) -> int:
	var index: int = active_potion_index
	for i: int in potion_slots.size():
		if potion_slots[i] == null:
			index = i
			break
	set_potion_slot(index, potion)
	return index


# Alterna o slot ativo entre 0 e 1 (direction não nula)
func cycle_potion(direction: int) -> void:
	if direction == 0:
		return
	active_potion_index = posmod(active_potion_index + direction, potion_slots.size())
	print("[Items] - Poção ativa: %d" % active_potion_index)
	EventBus.potion_selected.emit(active_potion_index)
	EventBus.active_effects_changed.emit()


# Efeitos da poção ativa (vazio se nula)
func get_active_effect_totals() -> Dictionary:
	var potion: PotionData = get_active_potion()
	return potion.effect_totals if potion != null else {}


# Limpa o estado para nova partida
func reset() -> void:
	owned_items.clear()
	bag_entries.clear()
	ground_entries.clear()
	pending_items.clear()
	starting_items_seeded = false
	shrink_upgrade_active = false
	floor_level = 1
	potion_slots = [null, null]
	active_potion_index = 0
	EventBus.potion_slots_changed.emit()
	EventBus.active_effects_changed.emit()


# Escala por andar: cada andar encolhe os itens por 1/FLOOR_SHRINK_FACTOR
func floor_scale() -> float:
	return pow(1.0 / FLOOR_SHRINK_FACTOR, floor_level - 1)


# Avança o andar; itens já na bolsa encolhem junto
func advance_floor() -> void:
	floor_level += 1
	for entry: Dictionary in bag_entries:
		entry["scale"] = float(entry["scale"]) / FLOOR_SHRINK_FACTOR
	print("[Items] - Andar %d (escala %.3f)" % [floor_level, floor_scale()])
	EventBus.floor_changed.emit(floor_level)


# Escala atual de um item: base * raridade * andar * (shrink se ativo e with_shrink)
func current_item_scale(item: ItemData = null, with_shrink: bool = true) -> float:
	var result: float = base_item_scale * floor_scale()
	if item != null:
		result *= item.rarity_scale()
	if with_shrink and shrink_upgrade_active:
		result *= shrink_scale
	return result


# Guarda o item na bolsa se couber facilmente
func try_auto_store(item: ItemData) -> bool:
	var scale_now: float = current_item_scale(item)
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


func _is_synergy_active(synergy: ItemSynergy, items: Array[ItemData]) -> bool:
	if synergy.required_items.is_empty():
		return false
	for req: ItemData in synergy.required_items:
		if not _contains(items, req):
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
