class_name BossHealthBar
extends CanvasLayer
## Barra de vida do boss no rodapé: moldura e preenchimento em 9-slice (arte HPBar), nome do boss, rastro do
## dano recebido e os ícones dos itens a que ele está imune (cada um com um X vermelho pequeno).
## Quando o boss se adapta, anuncia no centro da tela quais itens ele passou a ignorar.

const FRAME_TEXTURE: Texture2D = preload("res://assets/sprites/ui/BossHPBarFrame.png")
const FILL_TEXTURE: Texture2D = preload("res://assets/sprites/ui/BossHPBarFill.png")

## Tamanho da barra em pixels da arte (antes de bar_scale)
@export var bar_size: Vector2 = Vector2(140.0, 10.0)
## Escala da arte da barra (pixel art)
@export var bar_scale: float = 2.0
## Distância da barra até a borda de baixo da tela
@export var bottom_margin: float = 30.0
## Lado dos ícones de imunidade
@export var icon_size: float = 18.0
## Espera (s) antes do rastro de dano descer e duração da descida
@export var trail_delay: float = 0.35
@export var trail_time: float = 0.45
## Cor do X das imunidades
@export var cross_color: Color = Color(1.0, 0.15, 0.15)
## Cor do anúncio de adaptação
@export var announce_color: Color = Color(0.85, 0.55, 1.0)

var _boss: Boss
var _health: HealthComponent
var _root: Control
var _bar: Control
var _fill: NinePatchRect
var _trail: NinePatchRect
var _name_label: Label
var _icons: HBoxContainer
var _trail_tween: Tween


func _ready() -> void:
	_build()
	EventBus.boss_spawned.connect(_on_boss_spawned)
	EventBus.boss_adapted.connect(_on_boss_adapted)


# Monta a barra centralizada no rodapé (fica escondida até o boss surgir).
func _build() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var shown_size: Vector2 = bar_size * bar_scale
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.size = screen
	_root.visible = false
	add_child(_root)

	_bar = Control.new()
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.size = bar_size
	_bar.scale = Vector2.ONE * bar_scale
	_bar.position = Vector2((screen.x - shown_size.x) * 0.5, screen.y - bottom_margin - shown_size.y)
	_root.add_child(_bar)
	# Moldura atrás, rastro do dano e preenchimento por cima (o preenchimento encolhe a partir da esquerda)
	_bar.add_child(_make_patch(FRAME_TEXTURE, 2, 2, 2, 2))
	_trail = _make_patch(FILL_TEXTURE, 3, 2, 3, 2)
	_trail.modulate = Color(1.0, 1.0, 1.0, 0.45)
	_bar.add_child(_trail)
	_fill = _make_patch(FILL_TEXTURE, 3, 2, 3, 2)
	_bar.add_child(_fill)

	_name_label = Label.new()
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 12)
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 4)
	_name_label.size = Vector2(shown_size.x, 16.0)
	_name_label.position = _bar.position + Vector2(0.0, -17.0)
	_root.add_child(_name_label)

	_icons = HBoxContainer.new()
	_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icons.alignment = BoxContainer.ALIGNMENT_CENTER
	_icons.add_theme_constant_override("separation", 3)
	_icons.size = Vector2(shown_size.x, icon_size)
	_icons.position = _bar.position + Vector2(0.0, shown_size.y + 2.0)
	_root.add_child(_icons)


func _make_patch(texture: Texture2D, left: int, top: int, right: int, bottom: int) -> NinePatchRect:
	var patch: NinePatchRect = NinePatchRect.new()
	patch.texture = texture
	patch.patch_margin_left = left
	patch.patch_margin_top = top
	patch.patch_margin_right = right
	patch.patch_margin_bottom = bottom
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch.size = bar_size
	return patch


# Passa a acompanhar o boss novo: vida cheia, sem imunidades.
func _on_boss_spawned(boss: Node) -> void:
	_boss = boss as Boss
	if _boss == null:
		return
	_health = _boss.get_health()
	_health.health_changed.connect(_on_health_changed)
	_health.died.connect(_hide_bar)
	_boss.tree_exiting.connect(_hide_bar)
	_name_label.text = tr(_boss.display_name)
	for child: Node in _icons.get_children():
		child.queue_free()
	_set_fill_ratio(1.0, _fill)
	_set_fill_ratio(1.0, _trail)
	_root.visible = true
	_root.modulate.a = 0.0
	create_tween().tween_property(_root, "modulate:a", 1.0, 0.4)


# Preenchimento acompanha na hora; o rastro espera um pouco e desce suave.
func _on_health_changed(current: int, max_value: int) -> void:
	var ratio: float = clampf(float(current) / maxf(float(max_value), 1.0), 0.0, 1.0)
	_set_fill_ratio(ratio, _fill)
	if _trail_tween != null and _trail_tween.is_valid():
		_trail_tween.kill()
	if _trail.size.x <= _fill.size.x:
		_set_fill_ratio(ratio, _trail)
		return
	_trail_tween = create_tween()
	_trail_tween.tween_interval(trail_delay)
	_trail_tween.tween_method(_set_fill_ratio.bind(_trail), _trail.size.x / bar_size.x, ratio, trail_time).set_ease(Tween.EASE_OUT)


# Largura proporcional à vida; abaixo das bordas do 9-slice some (não dá para encolher mais que elas).
func _set_fill_ratio(ratio: float, patch: NinePatchRect) -> void:
	var width: float = bar_size.x * ratio
	var min_width: float = patch.patch_margin_left + patch.patch_margin_right
	patch.visible = width >= min_width
	patch.size = Vector2(maxf(width, min_width), bar_size.y)


# Boss morreu ou saiu da árvore (os dois sinais chegam; só o primeiro esconde).
func _hide_bar() -> void:
	if _boss == null or not is_inside_tree():
		return
	_boss = null
	var tween: Tween = create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func() -> void: _root.visible = false)


# Ícones das imunidades novas entram com pop na barra; o anúncio aparece no centro da tela.
func _on_boss_adapted(new_items: Array[ItemData], _all_immune: Array[ItemData]) -> void:
	var names: PackedStringArray = []
	for item: ItemData in new_items:
		var icon: Control = _make_immune_icon(item)
		_icons.add_child(icon)
		icon.pivot_offset = Vector2.ONE * icon_size * 0.5
		icon.scale = Vector2.ZERO
		icon.create_tween().tween_property(icon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		names.append(_item_name(item))
	_announce(tr("O BOSS SE ADAPTOU!"), tr("Agora é imune a: %s") % ", ".join(names))


# Ícone do item com um X vermelho pequeno no canto inferior direito.
func _make_immune_icon(item: ItemData) -> Control:
	var icon: TextureRect = TextureRect.new()
	icon.texture = item.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * icon_size
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.tooltip_text = _item_name(item)
	var cross: Control = Control.new()
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cross.set_anchors_preset(Control.PRESET_FULL_RECT)
	cross.draw.connect(_draw_cross.bind(cross))
	icon.add_child(cross)
	return icon


func _draw_cross(canvas: Control) -> void:
	var side: float = icon_size * 0.45
	var corner: Vector2 = Vector2(icon_size, icon_size)
	var a: Vector2 = corner - Vector2(side, side)
	# Contorno escuro para o X aparecer sobre qualquer ícone
	canvas.draw_line(a, corner, Color.BLACK, 3.0)
	canvas.draw_line(Vector2(corner.x, a.y), Vector2(a.x, corner.y), Color.BLACK, 3.0)
	canvas.draw_line(a, corner, cross_color, 1.5)
	canvas.draw_line(Vector2(corner.x, a.y), Vector2(a.x, corner.y), cross_color, 1.5)


func _item_name(item: ItemData) -> String:
	return tr(item.display_name) if item.display_name != "" else String(item.id)


# Título grande com pop e subtítulo; somem juntos subindo.
func _announce(title: String, subtitle: String) -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_make_announce_label(title, 22, announce_color))
	box.add_child(_make_announce_label(subtitle, 12, Color.WHITE))
	add_child(box)
	box.size = Vector2(screen.x, box.get_combined_minimum_size().y)
	box.pivot_offset = box.size * 0.5
	var start: Vector2 = Vector2(0.0, screen.y * 0.3)
	box.position = start
	box.scale = Vector2.ONE * 1.6
	var tween: Tween = box.create_tween()
	tween.tween_property(box, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.4)
	tween.tween_property(box, "position:y", start.y - 24.0, 0.6).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(box, "modulate:a", 0.0, 0.6)
	tween.tween_callback(box.queue_free)


func _make_announce_label(text: String, font_size: int, color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	return label
