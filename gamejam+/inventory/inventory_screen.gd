class_name InventoryScreen
extends CanvasLayer
## Tela do inventário físico: pausa o jogo e mostra a bolsa e o chão.

@export var spawn_area: Rect2 = Rect2(400, 40, 190, 80)
@export var drop_scatter: float = 24.0
@export var nearby_radius: float = 96.0
@export var max_nearby_items: int = 12
@export var spawn_columns: int = 4
@export var spawn_row_step: float = 50.0

var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _open: bool = false
# Item físico -> posição original no mundo (itens vindos do chão)
var _origins: Dictionary = {}
var _spawn_index: int = 0
var _frozen_scene: Node
var _prev_scene_mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT

@onready var _viewport: SubViewport = $ViewportContainer/SubViewport
@onready var _bag: Bag = $ViewportContainer/SubViewport/Bag
@onready var _tooltip: ItemTooltip = $ItemTooltip

func _ready() -> void:
	visible = false
	_build_screen_walls()
	EventBus.inventory_open_requested.connect(open)
	print("[Inventory] - Tela de inventário pronta")

# Alterna com a ação "inventory"; Esc fecha
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		if _open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

# Paredes invisíveis nas bordas do SubViewport
func _build_screen_walls() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	var s: Vector2 = Vector2(_viewport.size)
	var t: float = 48.0
	var rects: Array[Rect2] = [
		Rect2(-t, -t, s.x + 2.0 * t, t), Rect2(-t, s.y, s.x + 2.0 * t, t),
		Rect2(-t, 0, t, s.y), Rect2(s.x, 0, t, s.y),
	]
	for r: Rect2 in rects:
		var shape := RectangleShape2D.new()
		shape.size = r.size
		var col := CollisionShape2D.new()
		col.shape = shape
		col.position = r.get_center()
		body.add_child(col)
	_viewport.add_child(body)

# Abre a tela (ignorado se já aberta ou se o jogo já está pausado)
func open() -> void:
	if _open or get_tree().paused:
		return
	_open = true
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ItemManager.inventory_open = true
	for entry: Dictionary in ItemManager.bag_entries:
		_track(_bag.spawn_item(entry["item"], entry["position"], entry.get("rotation", 0.0), entry.get("scale", ItemManager.base_item_scale)))
	_spawn_index = 0
	_origins.clear()
	for entry: Dictionary in _nearby_ground_entries():
		ItemManager.take_from_ground(entry)
		var gi: PhysicalItem = _spawn_in_area(entry["item"])
		_origins[gi] = entry["position"]
	for data: ItemData in ItemManager.pending_items:
		_spawn_in_area(data)
	ItemManager.pending_items.clear()
	visible = true
	# Não usa get_tree().paused: pausar a árvore também pausa o PhysicsServer2D e congelaria os itens
	_frozen_scene = get_tree().current_scene
	_prev_scene_mode = _frozen_scene.process_mode
	_frozen_scene.process_mode = Node.PROCESS_MODE_DISABLED
	print("[Inventory] - Aberto (%d na bolsa)" % ItemManager.bag_entries.size())

# Fecha: salva a bolsa e derruba o resto no chão do mundo
func close() -> void:
	if not _open:
		return
	_open = false
	var kept: Array[Dictionary] = _bag.collect_entries()
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var origin: Vector2 = player.global_position if player != null else Vector2.ZERO
	var dropped: int = 0
	for child: Node in _bag.get_children():
		if child is PhysicalItem:
			var item := child as PhysicalItem
			if not _bag.is_inside(item):
				if _origins.has(item):
					ItemManager.drop_to_ground(item.item_data, _origins[item])
				else:
					var offset := Vector2(randf_range(-drop_scatter, drop_scatter), randf_range(-drop_scatter, drop_scatter))
					ItemManager.drop_to_ground(item.item_data, origin + offset if player != null else Vector2.ZERO)
				dropped += 1
			item.queue_free()
	_origins.clear()
	ItemManager.save_bag_layout(kept)
	_tooltip.clear()
	visible = false
	if is_instance_valid(_frozen_scene):
		_frozen_scene.process_mode = _prev_scene_mode
	_frozen_scene = null
	Input.mouse_mode = _prev_mouse_mode
	ItemManager.inventory_open = false
	EventBus.inventory_closed.emit()
	print("[Inventory] - Fechado (%d na bolsa, %d no chão)" % [kept.size(), dropped])

# Entradas do chão dentro do raio do player, as mais próximas primeiro
func _nearby_ground_entries() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return out
	for entry: Dictionary in ItemManager.ground_entries:
		if player.global_position.distance_to(entry["position"]) <= nearby_radius:
			out.append(entry)
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return player.global_position.distance_squared_to(x["position"]) < player.global_position.distance_squared_to(y["position"]))
	if out.size() > max_nearby_items:
		out.resize(max_nearby_items)
	print("[Inventory] - %d itens do chão por perto" % out.size())
	return out

# Spawna um item na spawn_area, escalonado em grade para não sobrepor
func _spawn_in_area(data: ItemData) -> PhysicalItem:
	var cols: int = maxi(spawn_columns, 1)
	var col: int = _spawn_index % cols
	var row: int = _spawn_index / cols
	_spawn_index += 1
	var pos: Vector2 = spawn_area.position + Vector2(
		(float(col) + 0.5) * spawn_area.size.x / float(cols),
		float(row) * spawn_row_step + randf_range(0.0, 6.0))
	var item: PhysicalItem = _bag.spawn_item(data, _bag.to_local(_viewport_to_global(pos)), randf() * TAU, ItemManager.current_item_scale())
	_track(item)
	return item

func _track(item: PhysicalItem) -> void:
	_tooltip.watch(item)

# Converte coordenada do SubViewport para o espaço global dele
func _viewport_to_global(p: Vector2) -> Vector2:
	return p
