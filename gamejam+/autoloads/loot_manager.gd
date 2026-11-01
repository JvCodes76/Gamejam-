extends Node
## Sistema de drop de itens. Todo drop sorteia primeiro a raridade (sorteio ponderado) e depois
## um item só entre os itens dessa raridade. As chances melhoram a cada cemitério completado e,
## de forma agressiva, a cada conjunto de cemitérios (loop do modo infinito) completado.
## Quem quer um drop emite EventBus.item_drop_requested(source, position); este autoload decide.

const ITEMS_DIR: String = "res://items/data/"

## Origem do drop (cada uma tem sua tabela)
enum Source {
	ITEM_ROOM,     # sala de item
	HORDE_CLEAR,   # sala de timer limpa antes do tempo acabar
	NORMAL_ENEMY,  # inimigo comum derrotado
	ELITE_ENEMY,   # elite derrotado
	BOSS_REWARD,   # arena do boss ao fim de um conjunto de cemitérios (sempre lendário)
	BOSS_HIT,      # dano no boss (a chance por dano fica no próprio Boss; aqui sempre dropa)
}

@export_group("Tabelas base")
## Pesos de raridade [Básico, Intermediário, Avançado, Lendário] da sala de item e da sala de timer
@export var room_rarity_weights: Array[float] = [75.0, 20.0, 4.0, 1.0]
## Pesos de raridade do drop de inimigo comum
@export var normal_rarity_weights: Array[float] = [75.0, 20.0, 4.0, 1.0]
## Pesos de raridade do drop de elite
@export var elite_rarity_weights: Array[float] = [25.0, 50.0, 20.0, 5.0]
## Pesos de raridade do drop por dano no boss
@export var boss_hit_rarity_weights: Array[float] = [40.0, 40.0, 17.0, 3.0]
## Chance (0-1) de um inimigo comum dropar item
@export var normal_drop_chance: float = 0.075
## Chance (0-1) de um elite dropar item
@export var elite_drop_chance: float = 0.25

@export_group("Melhoria por cemitério")
## Crescimento dos pesos por cemitério completado (0.15 = +15% do peso base por cemitério)
@export var cemetery_rarity_growth: Array[float] = [0.0, 0.15, 0.3, 0.4]
## Chance de drop somada por cemitério completado
@export var normal_drop_chance_per_cemetery: float = 0.005
@export var elite_drop_chance_per_cemetery: float = 0.02

@export_group("Melhoria por loop (agressiva)")
## Multiplicador extra dos pesos por loop completado (1.0 = dobra o peso a cada loop)
@export var loop_rarity_growth: Array[float] = [0.0, 0.5, 1.0, 1.5]
## Multiplicador extra da chance de drop por loop completado
@export var loop_drop_chance_growth: float = 0.25
## Tetos da chance de drop
@export var normal_drop_chance_cap: float = 0.2
@export var elite_drop_chance_cap: float = 0.6

## Cemitérios por loop (atualizado pelo sinal cemetery_changed)
var cemeteries_per_loop: int = 5

# Itens por raridade: Rarity -> Array[ItemData]
var _items_by_rarity: Dictionary = {}
# Lendário do boss ainda não recolhido: reaparece no spawn do próximo loop
var _unclaimed_boss_item: ItemData = null


func _ready() -> void:
	_load_items()
	EventBus.item_drop_requested.connect(_on_item_drop_requested)
	EventBus.cemetery_changed.connect(_on_cemetery_changed)
	EventBus.item_collected.connect(_on_item_collected)


## Cemitérios completados na run inteira (o loop atual conta os anteriores a ele).
func cemeteries_completed() -> int:
	return GameManager.loop_index * cemeteries_per_loop + maxi(GameManager.cemetery_index - 1, 0)


## Pesos de raridade já melhorados pelo progresso da run.
func rarity_weights(source: Source) -> Array[float]:
	var base: Array[float] = _base_weights(source)
	var done: int = cemeteries_completed()
	var loops: int = GameManager.loop_index
	var out: Array[float] = []
	for i: int in base.size():
		var growth: float = 1.0 + _at(cemetery_rarity_growth, i) * done
		var loop_growth: float = 1.0 + _at(loop_rarity_growth, i) * loops
		out.append(maxf(base[i] * growth * loop_growth, 0.0))
	return out


## Chance (0-1) de um inimigo dropar algo; salas sempre dropam.
func drop_chance(source: Source) -> float:
	var done: int = cemeteries_completed()
	var loop_mult: float = 1.0 + loop_drop_chance_growth * GameManager.loop_index
	match source:
		Source.NORMAL_ENEMY:
			return minf((normal_drop_chance + normal_drop_chance_per_cemetery * done) * loop_mult, normal_drop_chance_cap)
		Source.ELITE_ENEMY:
			return minf((elite_drop_chance + elite_drop_chance_per_cemetery * done) * loop_mult, elite_drop_chance_cap)
	return 1.0


## Sorteia um item para a origem (null = sem drop). Não solta no chão.
func roll_item(source: Source) -> ItemData:
	if randf() >= drop_chance(source):
		return null
	var rarity: ItemEnums.Rarity = ItemEnums.Rarity.LEGENDARY
	if source != Source.BOSS_REWARD:
		rarity = _roll_rarity(rarity_weights(source))
	return _roll_from_rarity(rarity)


## Sorteia e solta o item no chão. Retorna o item (null = sem drop).
func drop_item(source: Source, world_position: Vector2) -> ItemData:
	var item: ItemData = roll_item(source)
	if item == null:
		return null
	ItemManager.drop_to_ground(item, world_position)
	if source == Source.BOSS_REWARD:
		_unclaimed_boss_item = item
	print("[Loot] - %s dropou %s (%s)" % [Source.keys()[source], item.id, ItemEnums.Rarity.keys()[item.rarity]])
	return item


## Lendário do boss que ficou para trás (o modo infinito limpa o chão); devolve uma vez só.
func take_unclaimed_boss_item() -> ItemData:
	# Só existe dentro da mesma run, no início de um loop novo
	if GameManager.loop_index <= 0:
		_unclaimed_boss_item = null
		return null
	var item: ItemData = _unclaimed_boss_item
	_unclaimed_boss_item = null
	return item


# Sorteio ponderado de raridade; o índice do peso é o valor do enum Rarity
func _roll_rarity(weights: Array[float]) -> ItemEnums.Rarity:
	var total: float = 0.0
	for w: float in weights:
		total += w
	if total <= 0.0:
		return ItemEnums.Rarity.BASIC
	var pick: float = randf() * total
	for i: int in weights.size():
		pick -= weights[i]
		if pick < 0.0:
			return i as ItemEnums.Rarity
	return (weights.size() - 1) as ItemEnums.Rarity


# Item da raridade, preferindo os que o player ainda não tem; sem itens nela, desce de raridade
func _roll_from_rarity(rarity: ItemEnums.Rarity) -> ItemData:
	for r: int in range(rarity, -1, -1):
		var pool: Array = _items_by_rarity.get(r, [])
		if pool.is_empty():
			continue
		if r != rarity:
			push_warning("[Loot] - sem itens %s, caindo para %s" % [ItemEnums.Rarity.keys()[rarity], ItemEnums.Rarity.keys()[r]])
		var fresh: Array = pool.filter(func(item: ItemData) -> bool: return not _is_owned(item))
		return (fresh if not fresh.is_empty() else pool).pick_random()
	return null


func _base_weights(source: Source) -> Array[float]:
	match source:
		Source.NORMAL_ENEMY:
			return normal_rarity_weights
		Source.ELITE_ENEMY:
			return elite_rarity_weights
		Source.BOSS_HIT:
			return boss_hit_rarity_weights
	return room_rarity_weights


func _at(values: Array[float], index: int) -> float:
	return values[index] if index < values.size() else 0.0


# Já possuído, no chão ou esperando na tela de inventário
func _is_owned(item: ItemData) -> bool:
	for owned: ItemData in ItemManager.owned_items:
		if owned.id == item.id:
			return true
	for entry: Dictionary in ItemManager.ground_entries:
		if (entry["item"] as ItemData).id == item.id:
			return true
	for pending: ItemData in ItemManager.pending_items:
		if pending.id == item.id:
			return true
	return false


func _load_items() -> void:
	var dir: DirAccess = DirAccess.open(ITEMS_DIR)
	if dir == null:
		push_warning("[Loot] - pasta de itens não encontrada: %s" % ITEMS_DIR)
		return
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for file: String in files:
		# Em export, arquivos podem ter sufixo .remap
		var clean: String = file.trim_suffix(".remap")
		if not clean.ends_with(".tres"):
			continue
		var item: ItemData = load(ITEMS_DIR + clean) as ItemData
		if item == null:
			continue
		if not _items_by_rarity.has(item.rarity):
			_items_by_rarity[item.rarity] = []
		_items_by_rarity[item.rarity].append(item)
	for r: int in _items_by_rarity.keys():
		print("[Loot] - %d itens %s" % [_items_by_rarity[r].size(), ItemEnums.Rarity.keys()[r]])


func _on_item_drop_requested(source: int, world_position: Vector2) -> void:
	drop_item(source as Source, world_position)


func _on_cemetery_changed(_index: int, total: int) -> void:
	cemeteries_per_loop = maxi(total, 1)


func _on_item_collected(item_id: StringName, _position: Vector2) -> void:
	if _unclaimed_boss_item != null and _unclaimed_boss_item.id == item_id:
		_unclaimed_boss_item = null
