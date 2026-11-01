class_name ItemTooltip
extends PanelContainer

@export var mouse_offset: Vector2 = Vector2(14, 14)
@export var screen_margin: float = 4.0

const RARITY_NAMES: Dictionary = {
	ItemEnums.Rarity.BASIC: "Basic",
	ItemEnums.Rarity.INTERMEDIATE: "Intermediate",
	ItemEnums.Rarity.ADVANCED: "Advanced",
	ItemEnums.Rarity.LEGENDARY: "Legendary",
}
const ASPECT_NAMES: Dictionary = {
	ItemEnums.Aspect.PLANT: "Plant",
	ItemEnums.Aspect.POISON: "Poison",
	ItemEnums.Aspect.EARTH: "Earth",
	ItemEnums.Aspect.ROCK: "Rock",
	ItemEnums.Aspect.ANIMAL: "Animal",
	ItemEnums.Aspect.DARKNESS: "Darkness",
	ItemEnums.Aspect.LIGHT: "Light",
	ItemEnums.Aspect.MAGIC: "Magic",
	ItemEnums.Aspect.EVIL: "Evil",
}
const EFFECT_NAMES: Dictionary = {
	ItemEffect.EffectType.FIRE_DAMAGE: "Fire damage",
	ItemEffect.EffectType.POISON_DAMAGE: "Poison damage",
	ItemEffect.EffectType.LIFESTEAL: "Lifesteal",
	ItemEffect.EffectType.RANGE: "+Range",
	ItemEffect.EffectType.DAMAGE: "+Damage",
	ItemEffect.EffectType.FIRE_RATE: "+Fire rate",
	ItemEffect.EffectType.LUCK: "Luck",
	ItemEffect.EffectType.PIERCE: "+Pierce",
	ItemEffect.EffectType.CHARM_CHANCE: "Charm chance",
	ItemEffect.EffectType.HOMING: "Homing",
	ItemEffect.EffectType.AOE: "Area of effect",
	ItemEffect.EffectType.CRIT_DAMAGE: "Crit damage",
	ItemEffect.EffectType.LASER: "Laser",
	ItemEffect.EffectType.EXPLOSIVE: "Explosive",
	ItemEffect.EffectType.FIRE_BREATH: "Fire breath",
	ItemEffect.EffectType.REAL_BULLETS: "Real bullets",
	ItemEffect.EffectType.SPLIT: "+Split",
	ItemEffect.EffectType.BOUNCE: "+Bounce",
	ItemEffect.EffectType.POISON_CLOUD: "Poison cloud",
}

var _item: PhysicalItem

@onready var _name_label: Label = $VBox/NameLabel
@onready var _rarity_label: Label = $VBox/RarityLabel
@onready var _aspects_label: RichTextLabel = $VBox/AspectsLabel
@onready var _effects_label: Label = $VBox/EffectsLabel
@onready var _desc_label: Label = $VBox/DescLabel

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

# Connects the hover/grab signals of an item
func watch(item: PhysicalItem) -> void:
	item.hovered.connect(_on_hovered)
	item.unhovered.connect(_on_unhovered)
	item.released.connect(_on_released)

# Hides and forgets the current item
func clear() -> void:
	_item = null
	visible = false

func _on_hovered(item: PhysicalItem) -> void:
	_item = item
	_fill(item.item_data)
	visible = true
	_follow_mouse()

func _on_unhovered(item: PhysicalItem) -> void:
	if item == _item and not item.is_grabbed:
		clear()

func _on_released(item: PhysicalItem) -> void:
	if item == _item and not item.is_hovered:
		clear()

func _process(_delta: float) -> void:
	if visible:
		if _item == null or not is_instance_valid(_item):
			clear()
			return
		_follow_mouse()

# Positions near the mouse, keeping it inside the screen
func _follow_mouse() -> void:
	reset_size()
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var pos: Vector2 = get_viewport().get_mouse_position() + mouse_offset
	if pos.x + size.x > vp.x - screen_margin:
		pos.x = get_viewport().get_mouse_position().x - mouse_offset.x - size.x
	if pos.y + size.y > vp.y - screen_margin:
		pos.y = get_viewport().get_mouse_position().y - mouse_offset.y - size.y
	position = pos.clamp(Vector2.ONE * screen_margin, (vp - size - Vector2.ONE * screen_margin).max(Vector2.ZERO))

func _fill(data: ItemData) -> void:
	_name_label.text = data.display_name if data.display_name != "" else str(data.id)
	_rarity_label.text = RARITY_NAMES.get(data.rarity, "")
	_rarity_label.add_theme_color_override("font_color", ItemEnums.RARITY_COLORS.get(data.rarity, Color.WHITE))
	_aspects_label.text = _aspects_text(data)
	_effects_label.text = _effects_text(data)
	_effects_label.visible = _effects_label.text != ""
	_desc_label.text = data.description
	_desc_label.visible = data.description.strip_edges() != ""

# Groups repeated aspects, each in its own color (BBCode): "Animal x2, Plant"
func _aspects_text(data: ItemData) -> String:
	var counts: Dictionary = {}
	for a: ItemEnums.Aspect in data.aspects:
		counts[a] = int(counts.get(a, 0)) + 1
	var parts: PackedStringArray = []
	for a: ItemEnums.Aspect in counts:
		var n: int = counts[a]
		var text: String = ASPECT_NAMES.get(a, "?") + (" x%d" % n if n > 1 else "")
		var color: Color = ItemEnums.ASPECT_COLORS.get(a, Color.WHITE)
		parts.append("[color=#%s]%s[/color]" % [color.to_html(false), text])
	return ", ".join(parts)

# One line per effect; a magnitude other than 1 becomes "xN"
func _effects_text(data: ItemData) -> String:
	var lines: PackedStringArray = []
	for e: ItemEffect in data.effects:
		var line: String = EFFECT_NAMES.get(e.effect_type, "?")
		if not is_equal_approx(e.magnitude, 1.0):
			line += " x" + String.num(e.magnitude, 2)
		lines.append(line)
	return "\n".join(lines)
