class_name DungeonLevel
extends Node2D
## Um cemitério (andar da dungeon): gera o grafo de salas, monta o mapa contínuo e conduz as salas.
## O cemitério atual vem de GameManager.cemetery_index; o último termina na sala do boss.

const ITEMS_DIR: String = "res://items/data/"
# Folga entre a borda da sala e a área que conta como "dentro" (os pés do player precisam entrar)
const ROOM_TRIGGER_INSET: float = 40.0

@export_group("Cemitérios")
## Número de salas de cada cemitério (o tamanho do array é o número de cemitérios)
@export var rooms_per_cemetery: Array[int] = [6, 7, 8, 9, 10]
## Semente fixa para depurar (0 = aleatória a cada partida)
@export var fixed_seed: int = 0

@export_group("Mapa")
## Célula da grade em tiles (maior sala + corredor cabem nela)
@export var cell_pitch_tiles: Vector2i = Vector2i(64, 40)
## Largura do corredor e das portas: 4 tiles = 64 px, a largura do arco do tileset
@export var corridor_width_tiles: int = 4
## Multiplicador da quantidade de props decorativos
@export var prop_density: float = 1.0
## Largura (em tiles) da mata com grama, árvores e arbustos ao redor das grades
@export var exterior_margin_tiles: int = 12
## Multiplicador da quantidade de props da mata (0 = sem props)
@export var exterior_density: float = 1.0
@export var void_color: Color = Color.BLACK

@export_group("Salas extras")
## Pesos de sorteio das salas além de spawn/caldeirão/item/saída
@export var elite_room_weight: float = 1.0
@export var horde_room_weight: float = 1.0
@export var empty_room_weight: float = 1.0

@export_group("Inimigos")
@export var swarm_scenes: Array[PackedScene] = []
@export var elite_scene: PackedScene
@export var cauldron_scene: PackedScene
@export var cauldron_swarm_count: int = 8
@export var elite_room_count: int = 3
@export var horde_enemy_count: int = 18
@export var horde_time_limit: float = 30.0
@export var elite_health_multiplier: float = 6.0
@export var elite_scale: float = 1.5
@export var elite_tint: Color = Color(0.6, 0.7, 1.0)
@export var spawn_attempts: int = 12
@export var min_spawn_distance: float = 140.0

@export_group("Saída")
@export var portal_radius: float = 20.0

@export_group("Depuração")
# [DEBUG] Pinta cada sala com a cor do seu tipo (só para conversar sobre o layout)
@export var debug_room_colors: bool = false

var enemy_root: Node2D
var rooms: Array[RoomData] = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _encounters: Array[RoomEncounter] = []
var _player: Node2D
var _current_room: int = -1
var _portal_position: Vector2 = Vector2.INF
var _leaving: bool = false
var _previous_clear_color: Color


func _ready() -> void:
	_previous_clear_color = RenderingServer.get_default_clear_color()
	RenderingServer.set_default_clear_color(void_color)
	enemy_root = $Enemies as Node2D
	var damage_numbers: DamageNumbers = DamageNumbers.new()
	damage_numbers.name = "DamageNumbers"
	add_child(damage_numbers)
	_player = $Player as Node2D

	var total: int = rooms_per_cemetery.size()
	var index: int = clampi(GameManager.cemetery_index, 1, total)
	var is_final: bool = index == total
	_rng.seed = fixed_seed if fixed_seed != 0 else GameManager.run_seed + index
	var weights: Dictionary = {
		RoomData.Type.ELITE: elite_room_weight,
		RoomData.Type.HORDE: horde_room_weight,
		RoomData.Type.EMPTY: empty_room_weight,
	}
	rooms = DungeonGenerator.generate(rooms_per_cemetery[index - 1], is_final, weights, cell_pitch_tiles, DungeonBuilder.TILE, _rng)
	DungeonBuilder.new().build(self, rooms, corridor_width_tiles, prop_density, exterior_margin_tiles, exterior_density, _rng)
	_populate_rooms()
	var minimap: Minimap = get_node_or_null("Minimap") as Minimap
	if minimap != null:
		minimap.setup(rooms, _player)
	if debug_room_colors:
		_paint_debug_colors()
	_print_layout(index, total)
	EventBus.cemetery_changed.emit(index, total)


func _exit_tree() -> void:
	RenderingServer.set_default_clear_color(_previous_clear_color)


func _physics_process(_delta: float) -> void:
	if _player == null or _leaving:
		return
	var feet: Vector2 = _player.global_position
	var found: int = -1
	for i: int in rooms.size():
		if rooms[i].rect.grow(-ROOM_TRIGGER_INSET).has_point(feet):
			found = i
			break
	if found != -1 and found != _current_room:
		_current_room = found
		GameManager.advance_room()
		_encounters[found].on_player_entered()
	if _portal_position != Vector2.INF and feet.distance_to(_portal_position) <= portal_radius:
		_leaving = true
		print("[Dungeon] - saída do cemitério %d" % GameManager.cemetery_index)
		GameManager.advance_cemetery()


# Coloca o player, o caldeirão, o item e o portal; cria o encontro de cada sala.
func _populate_rooms() -> void:
	for room: RoomData in rooms:
		var encounter: RoomEncounter = RoomEncounter.new()
		encounter.name = "Encounter_%s" % RoomData.Type.keys()[room.type]
		encounter.setup(room, self)
		add_child(encounter)
		_encounters.append(encounter)
		match room.type:
			RoomData.Type.SPAWN:
				_player.global_position = room.center()
			RoomData.Type.CAULDRON:
				var cauldron: Node2D = cauldron_scene.instantiate() as Node2D
				cauldron.position = room.center()
				add_child(cauldron)
			RoomData.Type.ITEM:
				_drop_room_item(room)
			RoomData.Type.EXIT:
				_build_portal(room)


# Solta no centro da sala um item sorteado que o player ainda não tem.
func _drop_room_item(room: RoomData) -> void:
	var pool: Array[ItemData] = _item_pool()
	if pool.is_empty():
		print("[Dungeon] - sem itens para a sala de item")
		return
	var item: ItemData = pool[_rng.randi() % pool.size()]
	ItemManager.drop_to_ground(item, room.center())
	print("[Dungeon] - item da sala: %s" % item.id)


# Itens de ingrediente (sem os lendários) que o player ainda não possui; se acabarem, todos de novo.
func _item_pool() -> Array[ItemData]:
	var all_items: Array[ItemData] = []
	var dir: DirAccess = DirAccess.open(ITEMS_DIR)
	if dir == null:
		return all_items
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for file: String in files:
		var clean: String = file.trim_suffix(".remap")
		if not clean.ends_with(".tres"):
			continue
		var item: ItemData = load(ITEMS_DIR + clean) as ItemData
		if item != null and item.rarity != ItemEnums.Rarity.LEGENDARY:
			all_items.append(item)
	var fresh: Array[ItemData] = []
	for item: ItemData in all_items:
		if not _is_owned(item):
			fresh.append(item)
	return fresh if not fresh.is_empty() else all_items


func _is_owned(item: ItemData) -> bool:
	for owned: ItemData in ItemManager.owned_items:
		if owned.id == item.id:
			return true
	for entry: Dictionary in ItemManager.ground_entries:
		if (entry["item"] as ItemData).id == item.id:
			return true
	return false


# Portal roxo no centro da sala de saída (placeholder até existir o sprite).
func _build_portal(room: RoomData) -> void:
	_portal_position = room.center()
	var portal: Polygon2D = Polygon2D.new()
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 24:
		var a: float = TAU * float(i) / 24.0
		points.append(Vector2(cos(a) * portal_radius, sin(a) * portal_radius * 0.6))
	portal.polygon = points
	portal.color = RoomData.DEBUG_COLORS[RoomData.Type.EXIT]
	portal.position = _portal_position
	portal.z_index = -8
	add_child(portal)


# [DEBUG] Retângulo semitransparente na cor do tipo de cada sala.
func _paint_debug_colors() -> void:
	for room: RoomData in rooms:
		var overlay: Polygon2D = Polygon2D.new()
		var r: Rect2 = room.rect
		overlay.polygon = PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		overlay.color = Color(RoomData.DEBUG_COLORS[room.type], 0.28)
		overlay.z_index = -9
		add_child(overlay)


func _print_layout(index: int, total: int) -> void:
	var counts: Dictionary = {}
	for room: RoomData in rooms:
		var key: String = RoomData.Type.keys()[room.type]
		counts[key] = int(counts.get(key, 0)) + 1
	print("[Dungeon] - cemitério %d/%d: %d salas %s" % [index, total, rooms.size(), counts])
