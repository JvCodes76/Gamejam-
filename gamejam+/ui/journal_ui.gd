class_name JournalUi
extends CanvasLayer
## Journal / compendium: an open book with 3 sections (items, elemental synergies, special synergies) read page by page.
## Shows only what the player has discovered (see the Compendium autoload). Pauses the game while open.

enum Section { ITEMS, ELEMENTAL, SPECIAL }

const SHEET: Texture2D = preload("res://ui/journal_ui-Sheet.png")
const ELEMENTS: Texture2D = preload("res://ui/journal_ui_elements.png")

# The sheet frame is 256x192; this is the part with the book (integer scale keeps the pixel art crisp)
# (starts below the tabs drawn at the top of the sheet, which the book does not use)
const BOOK_REGION: Rect2 = Rect2(16.0, 28.0, 224.0, 150.0)
const BOOK_SCALE: float = 2.0
# Page areas, in sheet-frame pixels
const LEFT_PAGE: Rect2 = Rect2(36.0, 34.0, 84.0, 116.0)
const RIGHT_PAGE: Rect2 = Rect2(135.0, 34.0, 84.0, 116.0)
# Arrow sprites in the elements sheet: normal, hover, pressed
const ARROW_LEFT: Array[Rect2] = [Rect2(4.0, 83.0, 7.0, 11.0), Rect2(20.0, 83.0, 7.0, 11.0), Rect2(36.0, 84.0, 7.0, 10.0)]
const ARROW_RIGHT: Array[Rect2] = [Rect2(4.0, 99.0, 7.0, 11.0), Rect2(20.0, 99.0, 7.0, 11.0), Rect2(36.0, 100.0, 7.0, 10.0)]

# Entries per page of each section (items: 4, synergies: 2)
const PER_PAGE: Array[int] = [4, 2, 2]
const SECTION_NAMES: Array[String] = ["Items", "Elemental synergies", "Special synergies"]

const INK: Color = Color(0.28, 0.16, 0.10)
const INK_SOFT: Color = Color(0.28, 0.16, 0.10, 0.25)
const SPECIAL_COLOR: Color = Color(0.55, 0.3, 0.05)
const ICON_SIZE: float = 24.0
const SMALL_ICON: float = 16.0
const LINE_SPACING: int = -4

var _section: Section = Section.ITEMS
var _spread: int = 0
var _open: bool = false
var _prev_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_VISIBLE

var _root: Control
var _book: TextureRect
var _left: Control
var _right: Control
var _left_label: Label
var _right_label: Label
var _prev_button: TextureButton
var _next_button: TextureButton


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_build()
	EventBus.journal_open_requested.connect(open)
	EventBus.compendium_updated.connect(_on_compendium_updated)
	print("[Journal] - ready")


func _exit_tree() -> void:
	if _open:
		_open = false
		get_tree().paused = false
		ItemManager.journal_open = false
		print("[Journal] - unloaded with the journal open")


## Opens the book (only during play and when no other screen is up).
func open() -> void:
	if _open or get_tree().paused or ItemManager.inventory_open or GameManager.state != GameManager.State.PLAYING:
		return
	_open = true
	ItemManager.journal_open = true
	_prev_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	Compendium.has_unseen = false
	visible = true
	_refresh()
	EventBus.play_sfx_requested.emit("ui_click")
	print("[Journal] - opened")


## Closes the book and resumes the game.
func close() -> void:
	if not _open:
		return
	_open = false
	ItemManager.journal_open = false
	visible = false
	get_tree().paused = false
	Input.mouse_mode = _prev_mouse_mode
	EventBus.play_sfx_requested.emit("ui_click")
	print("[Journal] - closed")


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		if event.is_action_pressed("journal"):
			open()
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("journal") or event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		close()
	elif event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		_turn(-1)
	elif event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		_turn(1)
	# Everything else stays blocked while the book is open
	get_viewport().set_input_as_handled()


# --- Construction ---

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(_on_dim_input)
	_root.add_child(dim)
	var book_size: Vector2 = BOOK_REGION.size * BOOK_SCALE
	_book = TextureRect.new()
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = SHEET
	atlas.region = BOOK_REGION
	_book.texture = atlas
	_book.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_book.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_book.stretch_mode = TextureRect.STRETCH_SCALE
	_book.anchor_left = 0.5
	_book.anchor_right = 0.5
	_book.anchor_top = 0.5
	_book.anchor_bottom = 0.5
	_book.offset_left = -book_size.x * 0.5
	_book.offset_right = book_size.x * 0.5
	_book.offset_top = -book_size.y * 0.5
	_book.offset_bottom = book_size.y * 0.5
	_root.add_child(_book)
	_left = _make_page(LEFT_PAGE)
	_right = _make_page(RIGHT_PAGE)
	var footer_y: float = book_size.y - 44.0
	_prev_button = _make_arrow(ARROW_LEFT, Vector2(44.0, footer_y), -1)
	_next_button = _make_arrow(ARROW_RIGHT, Vector2(book_size.x - 44.0 - 14.0, footer_y), 1)
	# Section and page number at the foot of each page (between the arrows and the spine)
	var spine: float = book_size.x * 0.5
	_left_label = _make_footer(Vector2(64.0, footer_y), spine - 8.0 - 64.0)
	_right_label = _make_footer(Vector2(spine + 8.0, footer_y), book_size.x - 64.0 - spine - 8.0)
	var hint: Label = Label.new()
	hint.text = tr("Arrows / A D: turn page  ·  Esc or J: close")
	hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -14.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_style(hint, 8, Color(0.85, 0.8, 0.7))
	_root.add_child(hint)


# Page area (book-local pixels), clipped
func _make_page(frame_rect: Rect2) -> Control:
	var page: Control = Control.new()
	var local: Rect2 = _to_book(frame_rect)
	page.position = local.position
	page.size = local.size
	page.clip_contents = true
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_book.add_child(page)
	return page


func _make_footer(pos: Vector2, width: float) -> Label:
	var label: Label = Label.new()
	label.position = pos
	label.size = Vector2(width, 22.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	_style(label, 9, INK)
	_book.add_child(label)
	return label


func _make_arrow(sprites: Array[Rect2], pos: Vector2, direction: int) -> TextureButton:
	var button: TextureButton = TextureButton.new()
	button.texture_normal = _element(sprites[0])
	button.texture_hover = _element(sprites[1])
	button.texture_pressed = _element(sprites[2])
	button.texture_disabled = _element(sprites[0])
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.focus_mode = Control.FOCUS_NONE
	button.position = pos
	button.size = Vector2(14.0, 22.0)
	button.pressed.connect(_turn.bind(direction))
	_book.add_child(button)
	return button


func _element(region: Rect2) -> AtlasTexture:
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = ELEMENTS
	atlas.region = region
	return atlas


# Sheet-frame rectangle -> book-local rectangle
func _to_book(frame_rect: Rect2) -> Rect2:
	return Rect2((frame_rect.position - BOOK_REGION.position) * BOOK_SCALE, frame_rect.size * BOOK_SCALE)


# --- Navigation ---

# Turns one page spread; past the end of a section the book continues in the next one (and back again)
func _turn(direction: int) -> void:
	var section: int = _section
	var spread: int = _spread + direction
	if spread < 0:
		if section == Section.ITEMS:
			return
		section -= 1
		spread = _spread_count_of(section as Section) - 1
	elif spread >= _spread_count():
		if section == Section.SPECIAL:
			return
		section += 1
		spread = 0
	_section = section as Section
	_spread = spread
	EventBus.play_sfx_requested.emit("ui_click")
	_refresh()


func _on_dim_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		close()


func _on_compendium_updated() -> void:
	if _open:
		_refresh()


func _entries() -> Array:
	return _entries_of(_section)


func _entries_of(section: Section) -> Array:
	match section:
		Section.ELEMENTAL:
			return Compendium.discovered_elemental()
		Section.SPECIAL:
			return Compendium.discovered_specials()
	return Compendium.discovered_items()


func _spread_count() -> int:
	return _spread_count_of(_section)


func _spread_count_of(section: Section) -> int:
	return maxi(1, ceili(float(_entries_of(section).size()) / float(PER_PAGE[section] * 2)))


# --- Content ---

func _refresh() -> void:
	_spread = clampi(_spread, 0, _spread_count() - 1)
	var entries: Array = _entries()
	var per_page: int = PER_PAGE[_section]
	var start: int = _spread * per_page * 2
	_fill_page(_left, entries.slice(start, start + per_page))
	_fill_page(_right, entries.slice(start + per_page, start + per_page * 2))
	var count: int = _spread_count()
	_prev_button.disabled = _section == Section.ITEMS and _spread <= 0
	_next_button.disabled = _section == Section.SPECIAL and _spread >= count - 1
	_prev_button.modulate.a = 0.3 if _prev_button.disabled else 1.0
	_next_button.modulate.a = 0.3 if _next_button.disabled else 1.0
	var section_name: String = tr(SECTION_NAMES[_section])
	_left_label.text = "%s  ·  %d / %d" % [section_name, _spread * 2 + 1, count * 2]
	_right_label.text = "%s  ·  %d / %d" % [section_name, _spread * 2 + 2, count * 2]


func _fill_page(page: Control, entries: Array) -> void:
	for child: Node in page.get_children():
		child.queue_free()
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	box.size = page.size
	page.add_child(box)
	var slot_height: float = page.size.y / float(PER_PAGE[_section])
	for entry: Variant in entries:
		var slot: Control
		match _section:
			Section.ELEMENTAL:
				slot = _make_elemental_slot(entry as Dictionary, page.size.x, slot_height)
			Section.SPECIAL:
				slot = _make_special_slot(entry as Dictionary, page.size.x, slot_height)
			_:
				slot = _make_item_slot(entry as ItemData, page.size.x, slot_height)
		box.add_child(slot)


# Item: icon, name, aspects and description
func _make_item_slot(item: ItemData, width: float, height: float) -> Control:
	var slot: Control = _slot(width, height)
	var icon: TextureRect = _icon(item, ICON_SIZE)
	icon.position = Vector2(0.0, 2.0)
	slot.add_child(icon)
	var title: Label = Label.new()
	title.text = item.display_name if item.display_name != "" else String(item.id)
	title.position = Vector2(ICON_SIZE + 4.0, 0.0)
	title.size = Vector2(width - ICON_SIZE - 4.0, 12.0)
	title.clip_text = true
	var rarity_color: Color = ItemEnums.RARITY_COLORS.get(item.rarity, Color.WHITE)
	_style(title, 9, rarity_color.darkened(0.45))
	slot.add_child(title)
	var aspects: RichTextLabel = RichTextLabel.new()
	aspects.bbcode_enabled = true
	aspects.scroll_active = false
	aspects.autowrap_mode = TextServer.AUTOWRAP_OFF
	aspects.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aspects.position = Vector2(ICON_SIZE + 4.0, 12.0)
	aspects.size = Vector2(width - ICON_SIZE - 4.0, 13.0)
	aspects.add_theme_font_size_override("normal_font_size", 8)
	aspects.add_theme_color_override("default_color", INK)
	aspects.text = _aspects_text(item)
	slot.add_child(aspects)
	var desc: Label = Label.new()
	desc.text = item.description
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.position = Vector2(0.0, ICON_SIZE + 3.0)
	desc.size = Vector2(width, height - ICON_SIZE - 3.0)
	_style(desc, 8, INK)
	slot.add_child(desc)
	_add_divider(slot, width, height)
	return slot


# Elemental synergy: title, condition, effect and the discovered items of the element
func _make_elemental_slot(entry: Dictionary, width: float, height: float) -> Control:
	var aspect: int = entry["aspect"]
	var tier: int = entry["tier"]
	var aspect_name: String = tr(ItemTooltip.ASPECT_NAMES.get(aspect, "?"))
	var needed: int = SynergyConstants.TIER_THRESHOLDS[tier - 1]
	var slot: VBoxContainer = _synergy_slot(width, height)
	var color: Color = ItemEnums.ASPECT_COLORS.get(aspect, Color.WHITE)
	slot.add_child(_text("%s (%d)" % [aspect_name, needed], 10, color.darkened(0.35), width))
	slot.add_child(_text(tr("Condition: %d %s aspects in one potion.") % [needed, aspect_name], 8, INK, width))
	slot.add_child(_text(tr("Effect: %s") % _capitalized(SynergyResolver.tier_text(aspect, tier)), 8, INK, width))
	slot.add_child(_text(tr("Discovered ingredients:"), 8, INK, width))
	slot.add_child(_icon_flow(Compendium.discovered_items_with_aspect(aspect), width))
	return slot


# Special synergy: name, effect and the items of the recipe
func _make_special_slot(recipe: Dictionary, width: float, height: float) -> Control:
	var slot: VBoxContainer = _synergy_slot(width, height)
	slot.add_child(_text(String(recipe["name"]), 10, SPECIAL_COLOR, width))
	slot.add_child(_text(tr("Effect: %s") % _capitalized(String(recipe["description"])), 8, INK, width))
	slot.add_child(_text(tr("Condition: brew these together:"), 8, INK, width))
	var items: Array[ItemData] = []
	var names: PackedStringArray = []
	for id: StringName in recipe["item_ids"]:
		var item: ItemData = Compendium.get_item(id)
		if item != null:
			items.append(item)
			names.append(item.display_name if item.display_name != "" else String(id))
	slot.add_child(_icon_flow(items, width))
	slot.add_child(_text(", ".join(names), 8, INK, width))
	return slot


func _slot(width: float, height: float) -> Control:
	var slot: Control = Control.new()
	slot.custom_minimum_size = Vector2(width, height)
	slot.clip_contents = true
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return slot


func _synergy_slot(width: float, height: float) -> VBoxContainer:
	var slot: VBoxContainer = VBoxContainer.new()
	slot.custom_minimum_size = Vector2(width, height)
	slot.clip_contents = true
	slot.add_theme_constant_override("separation", 2)
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return slot


func _text(text: String, font_size: int, color: Color, width: float) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(width, 0.0)
	_style(label, font_size, color)
	return label


func _icon_flow(items: Array[ItemData], width: float) -> HFlowContainer:
	var flow: HFlowContainer = HFlowContainer.new()
	flow.custom_minimum_size = Vector2(width, 0.0)
	flow.add_theme_constant_override("h_separation", 2)
	flow.add_theme_constant_override("v_separation", 2)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for item: ItemData in items:
		var icon: TextureRect = _icon(item, SMALL_ICON)
		icon.mouse_filter = Control.MOUSE_FILTER_PASS
		icon.tooltip_text = item.display_name
		flow.add_child(icon)
	return flow


func _icon(item: ItemData, icon_size: float) -> TextureRect:
	var icon: TextureRect = TextureRect.new()
	icon.texture = item.icon
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


# Thin line at the bottom of the slot
func _add_divider(slot: Control, width: float, height: float) -> void:
	var line: ColorRect = ColorRect.new()
	line.color = INK_SOFT
	line.position = Vector2(0.0, height - 1.0)
	line.size = Vector2(width, 1.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(line)


# "[■] Plant, [■] Animal x2": a colored square plus the name in ink (the aspect colors do not read well on parchment)
func _aspects_text(item: ItemData) -> String:
	var counts: Dictionary = {}
	for a: int in item.aspects:
		counts[a] = int(counts.get(a, 0)) + 1
	var parts: PackedStringArray = []
	for a: int in counts:
		var n: int = counts[a]
		var label: String = tr(ItemTooltip.ASPECT_NAMES.get(a, "?")) + (" x%d" % n if n > 1 else "")
		var color: Color = ItemEnums.ASPECT_COLORS.get(a, Color.WHITE)
		parts.append("[color=#%s]■[/color] %s" % [color.to_html(false), label])
	return "  ".join(parts)


func _capitalized(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)


func _style(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	# The default font has a tall line height: tighten it so wrapped text fits the slots
	label.add_theme_constant_override("line_spacing", LINE_SPACING)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
