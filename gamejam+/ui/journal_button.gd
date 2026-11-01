class_name JournalButton
extends Control
## Closed-book icon in the bottom-right corner of the HUD: opens the journal and pulses on new discoveries.

const ICON_SCALE: float = 2.0
const NEW_DOT_COLOR: Color = Color(1.0, 0.85, 0.3)
# Pixel art of the book (12x14): O outline, H spine highlight, C cover, G gold, P pages
const PIXELS: PackedStringArray = [
	".OOOOOOOOOO.",
	"OHHHHHHHHCCO",
	"OHCCCCCCCCCO",
	"OHCCGGGGCCCO",
	"OHCCGCCGCCCO",
	"OHCCGGGGCCCO",
	"OHCCCCCCCCCO",
	"OHCCCGGCCCCO",
	"OHCCCCCCCCCO",
	"OHCCCCCCCCCO",
	"OPCCCCCCCCCO",
	"OPPPPPPPPPPO",
	"OPPPPPPPPPPO",
	".OOOOOOOOOO.",
]
const PALETTE: Dictionary = {
	"O": Color(0.30, 0.21, 0.12),
	"H": Color(0.66, 0.47, 0.40),
	"C": Color(0.40, 0.22, 0.19),
	"G": Color(0.75, 0.63, 0.50),
	"P": Color(0.93, 0.76, 0.60),
}

var _icon: TextureRect
var _dot: ColorRect
var _tween: Tween


func _ready() -> void:
	var tex: ImageTexture = _build_texture()
	var icon_size: Vector2 = Vector2(tex.get_size()) * ICON_SCALE
	custom_minimum_size = icon_size
	size = icon_size
	set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	offset_left = -icon_size.x - 12.0
	offset_top = -icon_size.y - 12.0
	offset_right = -12.0
	offset_bottom = -12.0
	pivot_offset = icon_size * 0.5
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = tr("Journal (J)")
	_icon = TextureRect.new()
	_icon.texture = tex
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_SCALE
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon)
	_dot = ColorRect.new()
	_dot.color = NEW_DOT_COLOR
	_dot.size = Vector2(6.0, 6.0)
	_dot.position = Vector2(icon_size.x - 5.0, -2.0)
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dot.visible = false
	add_child(_dot)
	EventBus.compendium_updated.connect(_on_compendium_updated)
	mouse_entered.connect(_set_hover.bind(true))
	mouse_exited.connect(_set_hover.bind(false))


func _process(_delta: float) -> void:
	_dot.visible = Compendium.has_unseen


func _gui_input(event: InputEvent) -> void:
	var click: InputEventMouseButton = event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		EventBus.journal_open_requested.emit()
		accept_event()


# A new entry was discovered: the book pops
func _on_compendium_updated() -> void:
	if _tween != null:
		_tween.kill()
	scale = Vector2.ONE * 1.4
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_hover(hovered: bool) -> void:
	modulate = Color(1.25, 1.25, 1.25) if hovered else Color.WHITE


func _build_texture() -> ImageTexture:
	var img: Image = Image.create(PIXELS[0].length(), PIXELS.size(), false, Image.FORMAT_RGBA8)
	for y: int in PIXELS.size():
		for x: int in PIXELS[y].length():
			var key: String = PIXELS[y][x]
			if PALETTE.has(key):
				img.set_pixel(x, y, PALETTE[key])
	return ImageTexture.create_from_image(img)
