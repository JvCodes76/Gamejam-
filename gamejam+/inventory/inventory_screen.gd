class_name InventoryScreen
extends CanvasLayer
## Tela do inventário físico: pausa o jogo e mostra a bolsa e o chão.

@export var ground_rect: Rect2 = Rect2(400, 70, 190, 220)
@export var drop_scatter: float = 24.0
@export var pending_margin: float = 30.0

var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _open: bool = false

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
	var t: float = 50.0
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
		_track(_bag.spawn_item(entry["item"], entry["position"], entry.get("rotation", 0.0), entry.get("scale", 1.0)))
	for data: ItemData in ItemManager.pending_items:
		var pos: Vector2 = ground_rect.position + Vector2(
			randf_range(pending_margin, ground_rect.size.x - pending_margin),
			randf_range(pending_margin, ground_rect.size.y - pending_margin))
		_track(_bag.spawn_item(data, _bag.to_local(_viewport_to_global(pos)), randf() * TAU, ItemManager.current_item_scale()))
	ItemManager.pending_items.clear()
	visible = true
	get_tree().paused = true
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
				var offset := Vector2(randf_range(-drop_scatter, drop_scatter), randf_range(-drop_scatter, drop_scatter))
				ItemManager.drop_to_ground(item.item_data, origin + offset if player != null else Vector2.ZERO)
				dropped += 1
			item.queue_free()
	ItemManager.save_bag_layout(kept)
	_tooltip.clear()
	visible = false
	get_tree().paused = false
	Input.mouse_mode = _prev_mouse_mode
	ItemManager.inventory_open = false
	EventBus.inventory_closed.emit()
	print("[Inventory] - Fechado (%d na bolsa, %d no chão)" % [kept.size(), dropped])

func _track(item: PhysicalItem) -> void:
	_tooltip.watch(item)

# Converte coordenada do SubViewport para o espaço global dele
func _viewport_to_global(p: Vector2) -> Vector2:
	return p
