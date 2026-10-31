class_name SynergyAnnouncement
extends Node
## Anúncio das sinergias especiais ao preparar a poção: explosão no caldeirão e o nome de cada receita
## flutuando até sumir no topo da tela. Não bloqueia a interação (nenhum nó captura o mouse).

# Labels de nome ativas (para consulta e limpeza)
var _labels: Array[Label] = []
var _origin: Vector2 = Vector2.ZERO
var _color: Color = Color.WHITE
var _pending: int = 0


## Cria o anúncio dentro de "layer" (CanvasLayer acima do inventário), a partir de "origin" (coordenadas de tela).
static func play(layer: Node, origin: Vector2, potion_color: Color, recipes: Array[Dictionary]) -> SynergyAnnouncement:
	var announcement: SynergyAnnouncement = SynergyAnnouncement.new()
	announcement.name = "SynergyAnnouncement"
	announcement.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(announcement)
	announcement._start(origin, potion_color, recipes)
	return announcement


## Labels de nome ainda vivas (para depuração e testes).
func active_labels() -> Array[Label]:
	var out: Array[Label] = []
	for label: Label in _labels:
		if is_instance_valid(label) and not label.is_queued_for_deletion():
			out.append(label)
	return out


func _start(origin: Vector2, potion_color: Color, recipes: Array[Dictionary]) -> void:
	_origin = origin
	_color = potion_color
	_pending = recipes.size()
	_spawn_explosion()
	EventBus.play_sfx_requested.emit("synergy")
	print("[Synergy] - anúncio: %d receita(s) especial(is)" % recipes.size())
	for i: int in recipes.size():
		var delay: float = SynergyConstants.ANNOUNCE_STAGGER * i
		if delay <= 0.0:
			_spawn_name(recipes[i], i)
		else:
			var tween: Tween = create_tween()
			tween.tween_interval(delay)
			tween.tween_callback(_spawn_name.bind(recipes[i], i))


## Explosão: burst grande de partículas quadradas, anel expansivo e flash branco curto.
func _spawn_explosion() -> void:
	ImpactEffect.spawn_burst(self, _origin, SynergyConstants.ANNOUNCE_BURST_RADIUS, _color, SynergyConstants.ANNOUNCE_BURST_PARTICLES,
		SynergyConstants.ANNOUNCE_BURST_LIFETIME, SynergyConstants.ANNOUNCE_RING_WIDTH, SynergyConstants.ANNOUNCE_BURST_SPEED_SCALE)
	var flash: ColorRect = ColorRect.new()
	flash.name = "Flash"
	flash.color = Color(1.0, 1.0, 1.0, SynergyConstants.ANNOUNCE_FLASH_ALPHA)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.size = get_viewport().get_visible_rect().size
	add_child(flash)
	var tween: Tween = flash.create_tween()
	tween.tween_property(flash, "color:a", 0.0, SynergyConstants.ANNOUNCE_FLASH_TIME)
	tween.tween_callback(flash.queue_free)


## Cria o nome (e a descrição abaixo) e anima a subida até sair pelo topo.
func _spawn_name(recipe: Dictionary, index: int) -> void:
	var gold: Color = SynergyConstants.ANNOUNCE_GOLD.lerp(_color, SynergyConstants.ANNOUNCE_COLOR_MIX)
	var label: Label = Label.new()
	label.name = "SynergyName%d" % index
	label.text = String(recipe["name"])
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", SynergyConstants.ANNOUNCE_NAME_FONT_SIZE)
	label.add_theme_color_override("font_color", gold)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", SynergyConstants.ANNOUNCE_OUTLINE_SIZE)
	label.add_theme_color_override("font_shadow_color", Color(gold, 0.55))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", SynergyConstants.ANNOUNCE_OUTLINE_SIZE + 2)
	add_child(label)
	label.size = label.get_minimum_size()
	var desc: Label = null
	var total_height: float = label.size.y
	if String(recipe.get("description", "")) != "":
		desc = Label.new()
		desc.name = "Description"
		desc.text = String(recipe["description"])
		desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desc.add_theme_font_size_override("font_size", SynergyConstants.ANNOUNCE_DESC_FONT_SIZE)
		desc.add_theme_color_override("font_color", Color(1.0, 0.97, 0.85))
		desc.add_theme_color_override("font_outline_color", Color.BLACK)
		desc.add_theme_constant_override("outline_size", 3)
		label.add_child(desc)
		desc.size = desc.get_minimum_size()
		desc.position = Vector2((label.size.x - desc.size.x) * 0.5, label.size.y - 2.0)
		total_height = desc.position.y + desc.size.y
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var step: int = (index + 1) / 2
	var side: float = 1.0 if index % 2 == 1 else -1.0
	var base_x: float = _origin.x - label.size.x * 0.5 + side * step * SynergyConstants.ANNOUNCE_X_STEP
	base_x = clampf(base_x, 4.0, maxf(screen.x - label.size.x - 4.0, 4.0))
	var start_y: float = _origin.y - label.size.y
	var end_y: float = -total_height
	label.position = Vector2(base_x, start_y)
	_labels.append(label)
	var tween: Tween = label.create_tween()
	tween.tween_method(_animate_name.bind(label, base_x, start_y, end_y), 0.0, 1.0, SynergyConstants.ANNOUNCE_FLOAT_TIME)
	tween.tween_callback(_finish_name.bind(label))
	print("[Synergy] - anúncio: %s" % label.text)


## Passo da animação (t de 0 a 1): sobe acelerando de leve, oscila no x e só some no trecho final.
func _animate_name(t: float, label: Label, base_x: float, start_y: float, end_y: float) -> void:
	if not is_instance_valid(label):
		return
	var rise: float = pow(t, SynergyConstants.ANNOUNCE_ACCEL_CURVE)
	label.position.y = lerpf(start_y, end_y, rise)
	label.position.x = base_x + sin(t * TAU * SynergyConstants.ANNOUNCE_WOBBLE_CYCLES) * SynergyConstants.ANNOUNCE_WOBBLE_AMPLITUDE
	var fade_start: float = 1.0 - SynergyConstants.ANNOUNCE_FADE_FRACTION
	label.modulate.a = 1.0 if t <= fade_start else clampf((1.0 - t) / SynergyConstants.ANNOUNCE_FADE_FRACTION, 0.0, 1.0)


## O nome saiu pelo topo: remove-o e libera o anúncio quando todos terminaram.
func _finish_name(label: Label) -> void:
	if is_instance_valid(label):
		label.queue_free()
	_pending -= 1
	if _pending <= 0:
		queue_free.call_deferred()
