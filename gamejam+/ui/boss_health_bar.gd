class_name BossHealthBar
extends CanvasLayer
## Boss health bar at the bottom: 9-slice frame and fill (HPBar art), boss name, trail of the
## damage taken and the icons of the items it is immune to (each with a small red X).
## When the boss adapts, announces in the center of the screen which items it now ignores.

const FRAME_TEXTURE: Texture2D = preload("res://assets/sprites/ui/BossHPBarFrame.png")
const FILL_TEXTURE: Texture2D = preload("res://assets/sprites/ui/BossHPBarFill.png")

## Bar size in art pixels (before bar_scale)
@export var bar_size: Vector2 = Vector2(140.0, 10.0)
## Scale of the bar art (pixel art)
@export var bar_scale: float = 2.0
## Distance from the bar to the bottom edge of the screen
@export var bottom_margin: float = 30.0
## Side length of the immunity icons
@export var icon_size: float = 18.0
## Wait (s) before the damage trail drops and the duration of the drop
@export var trail_delay: float = 0.35
@export var trail_time: float = 0.45
## Color of the immunity X
@export var cross_color: Color = Color(1.0, 0.15, 0.15)
## Color of the adaptation announcement
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


# Builds the bar centered at the bottom (hidden until the boss appears).
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
	# Frame behind, damage trail and fill on top (the fill shrinks from the left)
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


# Starts tracking the new boss: full health, no immunities.
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


# The fill follows instantly; the trail waits a bit and drops smoothly.
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


# Width proportional to health; below the 9-slice borders it disappears (it cannot shrink beyond them).
func _set_fill_ratio(ratio: float, patch: NinePatchRect) -> void:
	var width: float = bar_size.x * ratio
	var min_width: float = patch.patch_margin_left + patch.patch_margin_right
	patch.visible = width >= min_width
	patch.size = Vector2(maxf(width, min_width), bar_size.y)


# Boss died or left the tree (both signals arrive; only the first one hides).
func _hide_bar() -> void:
	if _boss == null or not is_inside_tree():
		return
	_boss = null
	var tween: Tween = create_tween()
	tween.tween_property(_root, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func() -> void: _root.visible = false)


# Icons of the new immunities pop onto the bar; the announcement appears in the center of the screen.
func _on_boss_adapted(new_items: Array[ItemData], _all_immune: Array[ItemData]) -> void:
	var names: PackedStringArray = []
	for item: ItemData in new_items:
		var icon: Control = _make_immune_icon(item)
		_icons.add_child(icon)
		icon.pivot_offset = Vector2.ONE * icon_size * 0.5
		icon.scale = Vector2.ZERO
		icon.create_tween().tween_property(icon, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		names.append(_item_name(item))
	_announce(tr("THE BOSS ADAPTED!"), tr("It is now immune to: %s") % ", ".join(names))


# Item icon with a small red X in the bottom-right corner.
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
	# Dark outline so the X shows over any icon
	canvas.draw_line(a, corner, Color.BLACK, 3.0)
	canvas.draw_line(Vector2(corner.x, a.y), Vector2(a.x, corner.y), Color.BLACK, 3.0)
	canvas.draw_line(a, corner, cross_color, 1.5)
	canvas.draw_line(Vector2(corner.x, a.y), Vector2(a.x, corner.y), cross_color, 1.5)


func _item_name(item: ItemData) -> String:
	return tr(item.display_name) if item.display_name != "" else String(item.id)


# Large title with pop and subtitle; they fade away together rising.
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
