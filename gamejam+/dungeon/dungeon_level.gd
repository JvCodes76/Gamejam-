class_name DungeonLevel
extends Node2D
## Um cemitério (andar da dungeon): gera o grafo de salas, monta o mapa contínuo e conduz as salas.
## O cemitério atual vem de GameManager.cemetery_index; o último termina na sala do boss.

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
@export var empty_room_weight: float = 0.0

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

@export_group("Boss")
## Cena do boss (placeholder: sem cena própria, usa o elite_scene ampliado)
@export var boss_scene: PackedScene
@export var boss_health_multiplier: float = 40.0
@export var boss_scale: float = 2.6
@export var boss_tint: Color = Color(1.0, 0.45, 0.45)
@export var boss_move_speed_multiplier: float = 0.8
@export var boss_points: int = 500

@export_group("Modo infinito")
## Vida extra dos inimigos por loop completado (0.6 = +60% por volta)
@export var loop_health_scaling: float = 0.6
## Dano de contato extra por loop (arredondado; 0.5 = +1 a cada 2 loops com dano base 1)
@export var loop_damage_scaling: float = 0.5
## Velocidade extra por loop, limitada por loop_max_speed_multiplier
@export var loop_speed_scaling: float = 0.08
@export var loop_max_speed_multiplier: float = 1.6
## Quantidade extra de inimigos por loop nas salas de enxame/horda/elite
@export var loop_count_scaling: float = 0.25
## Pontos extras por inimigo por loop
@export var loop_points_scaling: float = 0.5

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


## Multiplicador de vida dos inimigos no loop atual do modo infinito.
func loop_health_multiplier() -> float:
	return 1.0 + loop_health_scaling * GameManager.loop_index


## Multiplicador de dano de contato dos inimigos no loop atual.
func loop_damage_multiplier() -> float:
	return 1.0 + loop_damage_scaling * GameManager.loop_index


## Multiplicador de velocidade dos inimigos no loop atual (com teto).
func loop_speed_multiplier() -> float:
	return minf(1.0 + loop_speed_scaling * GameManager.loop_index, loop_max_speed_multiplier)


## Quantidade de inimigos escalada pelo loop atual (nunca menos que a base).
func loop_count(base: int) -> int:
	return maxi(base, roundi(base * (1.0 + loop_count_scaling * GameManager.loop_index)))


## Multiplicador de pontos por inimigo no loop atual.
func loop_points_multiplier() -> float:
	return 1.0 + loop_points_scaling * GameManager.loop_index


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
				_drop_boss_carryover(room)
			RoomData.Type.CAULDRON:
				var cauldron: Node2D = cauldron_scene.instantiate() as Node2D
				cauldron.position = room.center()
				add_child(cauldron)
			RoomData.Type.ITEM:
				_drop_room_item(room)
			RoomData.Type.EXIT:
				_build_portal(room)


# Sala de item: sorteio de raridade + item pelo LootManager, no centro da sala.
func _drop_room_item(room: RoomData) -> void:
	if LootManager.drop_item(LootManager.Source.ITEM_ROOM, room.center()) == null:
		print("[Dungeon] - sem itens para a sala de item")


# Lendário do boss não recolhido no loop anterior (o chão é limpo na virada): reaparece perto do spawn.
func _drop_boss_carryover(room: RoomData) -> void:
	var item: ItemData = LootManager.take_unclaimed_boss_item()
	if item == null:
		return
	ItemManager.drop_to_ground(item, room.center() + Vector2(0.0, -48.0))
	print("[Dungeon] - lendário do boss trazido para o spawn: %s" % item.id)


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
	print("[Dungeon] - loop %d, cemitério %d/%d: %d salas %s" % [GameManager.loop_index + 1, index, total, rooms.size(), counts])
