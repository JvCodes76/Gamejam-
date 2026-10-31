class_name InventoryScreen
extends CanvasLayer
## Tela do inventário físico: pausa o jogo e mostra a bolsa e o chão.

@export var spawn_area: Rect2 = Rect2(400, 40, 190, 80)
@export var drop_scatter: float = 24.0
@export var nearby_radius: float = 96.0
@export var max_nearby_items: int = 12
@export var spawn_columns: int = 4
@export var spawn_row_step: float = 50.0

# Modo caldeirão
@export var cauldron_vessel_scene: PackedScene = preload("res://cauldron/cauldron_vessel.tscn")
@export var cauldron_spawn_area: Rect2 = Rect2(274, 0, 100, 200)
@export var cauldron_spawn_columns: int = 2
@export var cauldron_spawn_row_step: float = 40.0
@export var bag_position_normal: Vector2 = Vector2(200, 200)
@export var bag_position_cauldron: Vector2 = Vector2(160, 200)
@export var vessel_position: Vector2 = Vector2(470, 210)
@export var brew_time: float = 3.0
# Quantas vezes mais rápido o progresso decai ao soltar o brew
@export var brew_decay_speed: float = 3.0
@export var melt_time: float = 0.4
@export var wobble_interval: float = 0.15
@export var wobble_impulse: float = 22.0
@export var toast_time: float = 1.6
@export var trash_position: Vector2 = Vector2(560, 230)
@export var picker_slot_gap: float = 48.0
@export var picker_dim_color: Color = Color(0, 0, 0, 0.6)
# Máximo de itens lendários por poção
@export var max_legendary_per_potion: int = 1
@export var sticking_tolerance: float = 1.5
@export var warning_hold_time: float = 1.0
@export var warning_refresh_interval: float = 0.2
@export var warning_color: Color = Color(1.0, 0.45, 0.25)
@export var conflict_tint: Color = Color(1.0, 0.6, 0.6)
@export var help_text_cauldron: String = "Drag items · Wheel rotates · Hold ENTER to brew · F to bottle · Tab/Esc to close"

var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE
var _open: bool = false
# Item físico -> posição original no mundo (itens vindos do chão)
var _origins: Dictionary = {}
var _spawn_index: int = 0
var _frozen_scene: Node
var _prev_scene_mode: Node.ProcessMode = Node.PROCESS_MODE_INHERIT
var _cauldron: Cauldron = null
var _vessel: CauldronVessel = null
var _wobble_timer: float = 0.0
var _help_normal: String = ""
var _brew_bar: ProgressBar
var _brew_label: Label
var _toast: Label
var _toast_tween: Tween
var _picker: Control = null
var _picker_slots: Array[PotionSlot] = []
var _trash: TrashButton
var _warn_timer: float = 0.0
var _warn_active: bool = false
var _highlight_timer: float = 0.0
var _tinted: Array[PhysicalItem] = []
# CanvasLayer acima do inventário para o anúncio das sinergias especiais
var _announce_layer: CanvasLayer = null

@onready var _viewport: SubViewport = $ViewportContainer/SubViewport
@onready var _bag: Bag = $ViewportContainer/SubViewport/Bag
@onready var _tooltip: ItemTooltip = $ItemTooltip
@onready var _help: Label = $HelpLabel

func _ready() -> void:
	visible = false
	_build_screen_walls()
	EventBus.inventory_open_requested.connect(open)
	EventBus.cauldron_open_requested.connect(_on_cauldron_open_requested)
	_help_normal = _help.text
	_build_brew_ui()
	_announce_layer = CanvasLayer.new()
	_announce_layer.name = "AnnounceLayer"
	_announce_layer.layer = layer + 1
	_announce_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_announce_layer)
	print("[Inventory] - Tela de inventário pronta")

# Alterna com a ação "inventory"; Esc fecha
func _unhandled_input(event: InputEvent) -> void:
	if _picker != null:
		if event.is_action_pressed("ui_cancel"):
			_close_picker()
		elif event.is_action_pressed("inventory"):
			close()
		else:
			return
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("inventory"):
		if _open:
			close()
		else:
			open()
		get_viewport().set_input_as_handled()
	elif _open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
	elif _open and _cauldron != null and event.is_action_pressed("bottle"):
		bottle()
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

func _on_cauldron_open_requested(cauldron: Node) -> void:
	open_cauldron(cauldron as Cauldron)


# Abre a tela (ignorado se já aberta ou se o jogo já está pausado)
func open() -> void:
	_begin_open(null)


# Abre a tela em modo caldeirão
func open_cauldron(cauldron: Cauldron) -> void:
	if cauldron == null:
		return
	_begin_open(cauldron)


func _begin_open(cauldron: Cauldron) -> void:
	if _open or get_tree().paused:
		return
	_open = true
	_cauldron = cauldron
	_bag.position = bag_position_cauldron if cauldron != null else bag_position_normal
	_help.text = help_text_cauldron if cauldron != null else _help_normal
	_set_brew_ui_visible(cauldron != null)
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	ItemManager.inventory_open = true
	for entry: Dictionary in ItemManager.bag_entries:
		_track(_bag.spawn_item(entry["item"], entry["position"], entry.get("rotation", 0.0), entry.get("scale", ItemManager.current_item_scale(entry["item"]))))
	_spawn_index = 0
	_origins.clear()
	if _cauldron != null:
		_open_vessel()
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
	print("[Inventory] - Aberto (%d na bolsa%s)" % [ItemManager.bag_entries.size(), ", modo caldeirão" if _cauldron != null else ""])

# Fecha: salva a bolsa (e o caldeirão) e derruba o resto no chão do mundo
func close() -> void:
	if not _open:
		return
	_open = false
	_tinted.clear()
	_warn_active = false
	_close_picker()
	var kept: Array[Dictionary] = _entries_in(_bag)
	if _cauldron != null:
		_cauldron.state.entries = _entries_in(_vessel)
		_cauldron.state.brew_progress = 0.0
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var origin: Vector2 = player.global_position if player != null else Vector2.ZERO
	var dropped: int = 0
	for item: PhysicalItem in _all_items():
		if not _bag.is_inside(item) and not _in_vessel(item):
			if _origins.has(item):
				ItemManager.drop_to_ground(item.item_data, _origins[item])
			else:
				var offset := Vector2(randf_range(-drop_scatter, drop_scatter), randf_range(-drop_scatter, drop_scatter))
				ItemManager.drop_to_ground(item.item_data, origin + offset if player != null else Vector2.ZERO)
			dropped += 1
		item.queue_free()
	if _vessel != null:
		_vessel.queue_free()
		_vessel = null
	_cauldron = null
	_set_brew_ui_visible(false)
	for child: Node in _announce_layer.get_children():
		child.queue_free()
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
	var area: Rect2 = spawn_area if _cauldron == null else cauldron_spawn_area
	var cols: int = maxi(spawn_columns if _cauldron == null else cauldron_spawn_columns, 1)
	var row_step: float = spawn_row_step if _cauldron == null else cauldron_spawn_row_step
	var col: int = _spawn_index % cols
	var row: int = _spawn_index / cols
	_spawn_index += 1
	var pos: Vector2 = area.position + Vector2(
		(float(col) + 0.5) * area.size.x / float(cols),
		float(row) * row_step + randf_range(0.0, 6.0))
	var item: PhysicalItem = _bag.spawn_item(data, _bag.to_local(_viewport_to_global(pos)), randf() * TAU, ItemManager.current_item_scale(data))
	_track(item)
	return item

func _track(item: PhysicalItem) -> void:
	_tooltip.watch(item)

# Converte coordenada do SubViewport para o espaço global dele
func _viewport_to_global(p: Vector2) -> Vector2:
	return p


# Cria o caldeirão físico e restaura itens e líquido do estado
func _open_vessel() -> void:
	var state: CauldronState = _cauldron.state
	_vessel = cauldron_vessel_scene.instantiate() as CauldronVessel
	_vessel.size_multiplier = state.size_multiplier
	_vessel.position = vessel_position
	_viewport.add_child(_vessel)
	for entry: Dictionary in state.entries:
		_track(_vessel.spawn_item(entry["item"], entry["position"], entry.get("rotation", 0.0), entry.get("scale", ItemManager.current_item_scale(entry["item"]))))
	if state.potion != null:
		_vessel.show_potion(state.potion)
	state.brew_progress = 0.0
	_layout_brew_ui()
	_refresh_brew_ui()


# Todos os itens vivos nas duas bolsas (inclui os que estão derretendo)
func _all_items(include_melting: bool = true) -> Array[PhysicalItem]:
	var out: Array[PhysicalItem] = []
	var holders: Array[Node] = [_bag]
	if _vessel != null:
		holders.append(_vessel)
	for holder: Node in holders:
		for child: Node in holder.get_children():
			var item := child as PhysicalItem
			if item == null or item.is_queued_for_deletion():
				continue
			if not include_melting and item.has_meta("melting"):
				continue
			out.append(item)
	return out


func _in_vessel(item: PhysicalItem) -> bool:
	return _vessel != null and _vessel.is_inside(item)


# Entradas de persistência dos itens (não derretendo) cujo centro está no recipiente
func _entries_in(container: Bag) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for item: PhysicalItem in _all_items(false):
		if container.is_inside(item):
			out.append({"item": item.item_data, "position": container.to_local(item.global_position), "rotation": item.global_rotation, "scale": item.item_scale})
	return out


func _process(delta: float) -> void:
	if not _open or _cauldron == null:
		return
	var state: CauldronState = _cauldron.state
	var items: Array[PhysicalItem] = [] as Array[PhysicalItem]
	items.assign(_vessel.collect_items().filter(func(i: PhysicalItem) -> bool: return not i.has_meta("melting")))
	var pressed: bool = Input.is_action_pressed("brew") and state.potion == null and _picker == null
	var blocker: String = ""
	if pressed and not items.is_empty():
		blocker = _brew_blocker(items)
	_update_warning(pressed, blocker, delta)
	_highlight_timer -= delta
	if _highlight_timer <= 0.0:
		_highlight_timer = warning_refresh_interval
		_update_highlight(items)
	var brewing: bool = pressed and not items.is_empty() and blocker == ""
	if brewing:
		state.brew_progress = minf(state.brew_progress + delta / brew_time, 1.0)
		_wobble_timer -= delta
		if _wobble_timer <= 0.0:
			_wobble_timer = wobble_interval
			for item: PhysicalItem in items:
				if not item.is_grabbed:
					item.apply_central_impulse(Vector2(randf_range(-1.0, 1.0), -randf()) * wobble_impulse)
		if state.brew_progress >= 1.0:
			_complete_brew(items)
	else:
		state.brew_progress = maxf(state.brew_progress - delta / brew_time * brew_decay_speed, 0.0)
	_vessel.set_brewing(brewing and state.potion == null)
	_refresh_brew_ui()


# Motivo que impede o preparo ("" se livre); itens para fora têm prioridade
func _brew_blocker(items: Array[PhysicalItem]) -> String:
	if not _sticking_items().is_empty():
		return "Items sticking out of the cauldron can't be brewed"
	if _legendary_items(items).size() > max_legendary_per_potion:
		return "Only one legendary item per potion"
	return ""


# Itens lendários no caldeirão se excederem o limite (senão vazio)
func _legendary_items(items: Array[PhysicalItem]) -> Array[PhysicalItem]:
	var out: Array[PhysicalItem] = []
	for item: PhysicalItem in items:
		if item.item_data.rarity == ItemEnums.Rarity.LEGENDARY:
			out.append(item)
	if out.size() <= max_legendary_per_potion:
		out.clear()
	return out


## Itens no caldeirão (centro dentro, ou contorno sobreposto ao interior) cujo contorno sai do interior.
func _sticking_items() -> Array[PhysicalItem]:
	var out: Array[PhysicalItem] = []
	if _vessel == null:
		return out
	var to_vessel: Transform2D = _vessel.global_transform.affine_inverse()
	var expanded: PackedVector2Array = _expanded_interior()
	for item: PhysicalItem in _all_items(false):
		if item.item_data == null:
			continue
		var xf: Transform2D = to_vessel * item.global_transform
		var center_in: bool = _vessel.is_inside(item) or _vessel.mouth_rect.grow(sticking_tolerance).has_point(xf.origin)
		var touches: bool = center_in
		var sticks: bool = false
		for poly: PackedVector2Array in ColliderBuilder.build_polygons(item.item_data.icon, item.item_scale, item.polygon_epsilon):
			var world: PackedVector2Array = Transform2D(xf.get_rotation(), xf.origin) * poly
			if not touches and _area_sum(Geometry2D.intersect_polygons(world, _vessel.interior)) > 1.0:
				touches = true
			if not sticks and _area_sum(Geometry2D.clip_polygons(world, expanded)) > 0.5:
				sticks = true
		if touches and sticks:
			out.append(item)
	return out


# Interior do vaso expandido pela tolerância
func _expanded_interior() -> PackedVector2Array:
	var res: Array[PackedVector2Array] = Geometry2D.offset_polygon(_vessel.interior, sticking_tolerance)
	return res[0] if not res.is_empty() else _vessel.interior


static func _area_sum(polys: Array[PackedVector2Array]) -> float:
	var sum: float = 0.0
	for poly: PackedVector2Array in polys:
		sum += absf(CauldronVessel._area(poly))
	return sum


# Mostra/limpa o aviso: aparece ao apertar brew com bloqueio e fica 1 s após soltar
func _update_warning(pressed: bool, blocker: String, delta: float) -> void:
	if pressed:
		if blocker != "":
			if not _warn_active:
				print("[Cauldron] - Preparo bloqueado: %s" % blocker)
			_show_warning(blocker)
		elif _warn_active:
			_clear_warning()
	elif _warn_active:
		_warn_timer -= delta
		if _warn_timer <= 0.0:
			_clear_warning()


func _show_warning(text: String) -> void:
	_warn_active = true
	_warn_timer = warning_hold_time
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.text = text
	_toast.add_theme_color_override("font_color", warning_color)
	_toast.modulate.a = 1.0


func _clear_warning() -> void:
	_warn_active = false
	_toast.modulate.a = 0.0
	_toast.add_theme_color_override("font_color", Color(1, 0.9, 0.5))


# Avermelha itens em conflito (para fora ou lendários em excesso); restaura os demais
func _update_highlight(items: Array[PhysicalItem]) -> void:
	var bad: Array[PhysicalItem] = _sticking_items()
	for item: PhysicalItem in _legendary_items(items):
		if not bad.has(item):
			bad.append(item)
	for item: PhysicalItem in _tinted:
		if is_instance_valid(item) and not bad.has(item):
			item.modulate = Color(1, 1, 1, item.modulate.a)
	for item: PhysicalItem in bad:
		item.modulate = Color(conflict_tint.r, conflict_tint.g, conflict_tint.b, item.modulate.a)
	_tinted = bad


# Derrete os itens e cria a poção
func _complete_brew(items: Array[PhysicalItem]) -> void:
	var datas: Array[ItemData] = []
	var scales: Array[float] = []
	for item: PhysicalItem in items:
		datas.append(item.item_data)
		scales.append(item.item_scale)
		_melt(item)
	var state: CauldronState = _cauldron.state
	state.potion = PotionData.from_items(datas, scales)
	state.entries.clear()
	state.brew_progress = 0.0
	_vessel.show_potion(state.potion)
	_vessel.set_brewing(false)
	_toast_message("Potion brewed! Press F to bottle")
	print("[Cauldron] - Preparo concluído (%d itens, volume %.1f)" % [datas.size(), state.potion.volume])
	_announce_special_synergies(state.potion)


## Explosão no caldeirão e nomes das receitas especiais subindo até o topo (não bloqueia a interação).
func _announce_special_synergies(potion: PotionData) -> void:
	var recipes: Array[Dictionary] = SpecialSynergies.recipes_for(potion.special_synergies)
	if recipes.is_empty() or _vessel == null:
		return
	var origin: Vector2 = _vessel.to_global(_vessel.mouth_rect.get_center())
	SynergyAnnouncement.play(_announce_layer, origin, potion.color, recipes)


# Anima o item sumindo e o libera
func _melt(item: PhysicalItem) -> void:
	item.set_meta("melting", true)
	item.freeze = true
	item.collision_layer = 0
	item.collision_mask = 0
	var tween: Tween = item.create_tween().set_parallel(true)
	tween.tween_property(item, "modulate:a", 0.0, melt_time)
	tween.tween_property(item, "scale", Vector2(0.3, 0.3), melt_time)
	tween.chain().tween_callback(item.queue_free)


## Abre o seletor de slots com a poção pronta (ação "bottle").
func bottle() -> void:
	if _cauldron == null or _picker != null:
		return
	if _cauldron.state.potion == null:
		_toast_message("Nothing to bottle yet")
		print("[Cauldron] - Nada para engarrafar")
		return
	_open_picker()


## Guarda a poção pronta no slot escolhido e limpa o caldeirão.
func _store_in_slot(index: int) -> void:
	var replaced: bool = ItemManager.potion_slots[index] != null
	ItemManager.set_potion_slot(index, _cauldron.state.potion)
	_clear_cauldron_potion()
	_close_picker()
	_toast_message(("Replaced potion in slot %d" if replaced else "Potion stored in slot %d") % (index + 1))
	print("[Cauldron] - Poção guardada no slot %d (substituiu: %s)" % [index, str(replaced)])


## Descarta a poção pronta (os itens já foram derretidos).
func discard_potion() -> void:
	if _cauldron == null or _picker != null or _cauldron.state.potion == null:
		return
	_clear_cauldron_potion()
	_toast_message("Potion discarded")
	print("[Cauldron] - Poção descartada")


func _clear_cauldron_potion() -> void:
	_cauldron.state.potion = null
	_vessel.clear_potion()
	_refresh_brew_ui()


## Cria o seletor central com os slots de poção.
func _open_picker() -> void:
	_picker = ColorRect.new()
	(_picker as ColorRect).color = picker_dim_color
	_picker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_picker.mouse_filter = Control.MOUSE_FILTER_STOP
	_picker.gui_input.connect(_on_picker_backdrop_input)
	add_child(_picker)
	_viewport.get_parent().mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picker_slots.clear()
	var count: int = ItemManager.potion_slots.size()
	var slot_size: Vector2 = PotionSlot.FLASK.get_size() * 3.0
	var total: float = count * slot_size.x + (count - 1) * picker_slot_gap
	var start := Vector2((640.0 - total) * 0.5, 180.0 - slot_size.y * 0.5)
	_picker.add_child(_make_label("Choose a slot", 14, Vector2(0, start.y - 36.0)))
	_picker.add_child(_make_label("Click a slot to store the potion · Esc cancels", 10, Vector2(0, start.y + slot_size.y + 28.0)))
	for i: int in count:
		var slot := PotionSlot.new()
		slot.label_text = str(i + 1)
		slot.position = start + Vector2(i * (slot_size.x + picker_slot_gap), 0)
		slot.mouse_filter = Control.MOUSE_FILTER_STOP
		slot.gui_input.connect(_on_picker_slot_input.bind(i))
		slot.mouse_entered.connect(_refresh_picker.bind(i))
		slot.mouse_exited.connect(_refresh_picker.bind(-1))
		_picker.add_child(slot)
		_picker_slots.append(slot)
	_refresh_picker(-1)
	print("[Cauldron] - Seletor de slots aberto")


func _make_label(text: String, font_size: int, pos: Vector2) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = pos
	label.size = Vector2(640, 16)
	return label


# Destaca o slot sob o mouse (hovered) e marca o slot ativo com "*"
func _refresh_picker(hovered: int) -> void:
	for i: int in _picker_slots.size():
		var potion: PotionData = ItemManager.potion_slots[i]
		var slot: PotionSlot = _picker_slots[i]
		slot.label_text = "%d%s" % [i + 1, " *" if i == ItemManager.active_potion_index else ""]
		slot.set_state(potion != null, potion.color if potion != null else Color.WHITE, i == hovered)


func _on_picker_slot_input(event: InputEvent, index: int) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_store_in_slot(index)
		_picker_accept()


func _on_picker_backdrop_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		_close_picker()
		print("[Cauldron] - Seletor cancelado")


func _picker_accept() -> void:
	get_viewport().set_input_as_handled()


func _close_picker() -> void:
	if _picker == null:
		return
	_picker.queue_free()
	_picker = null
	_picker_slots.clear()
	_viewport.get_parent().mouse_filter = Control.MOUSE_FILTER_STOP


# Cria a barra de progresso, o rótulo e a mensagem (fora do SubViewport)
func _build_brew_ui() -> void:
	_brew_bar = ProgressBar.new()
	_brew_bar.max_value = 1.0
	_brew_bar.step = 0.001
	_brew_bar.show_percentage = false
	_brew_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brew_bar.custom_minimum_size = Vector2(120, 6)
	_brew_bar.size = Vector2(120, 6)
	add_child(_brew_bar)
	_brew_label = Label.new()
	_brew_label.add_theme_font_size_override("font_size", 10)
	_brew_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_brew_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_brew_label.size = Vector2(160, 14)
	add_child(_brew_label)
	_toast = Label.new()
	_toast.add_theme_font_size_override("font_size", 12)
	_toast.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.position = Vector2(0, 14)
	_toast.size = Vector2(640, 16)
	_toast.modulate.a = 0.0
	add_child(_toast)
	_trash = TrashButton.new()
	_trash.position = trash_position
	_trash.pressed.connect(discard_potion)
	add_child(_trash)
	_set_brew_ui_visible(false)


func _set_brew_ui_visible(value: bool) -> void:
	_brew_bar.visible = value
	_brew_label.visible = value
	_trash.visible = false


# Posiciona a barra embaixo do caldeirão
func _layout_brew_ui() -> void:
	var bottom: float = vessel_position.y + 55.0 * _cauldron.state.size_multiplier + CauldronLayout.WALL_THICKNESS + 6.0
	_brew_bar.position = Vector2(vessel_position.x - 60.0, bottom)
	_brew_label.position = Vector2(vessel_position.x - 80.0, bottom + 8.0)


func _refresh_brew_ui() -> void:
	var state: CauldronState = _cauldron.state
	_brew_bar.value = state.brew_progress
	_brew_label.text = "Bottle: F" if state.potion != null else "Hold ENTER to brew"
	_trash.visible = state.potion != null


# Mensagem curta no topo que some sozinha
func _toast_message(text: String) -> void:
	_warn_active = false
	_toast.add_theme_color_override("font_color", Color(1, 0.9, 0.5))
	_toast.text = text
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(toast_time)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.4)
