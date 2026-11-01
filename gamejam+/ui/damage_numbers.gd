class_name DamageNumbers
extends Node2D
## Floating damage numbers in the world, with a fixed Label pool (no allocation in hordes).
## Normal: white. Critical: bigger, orange, with "!" and pop. DoT: smaller, in the source color, grouped ticks. Negated: "BLOCK".

enum Style { NORMAL, CRIT, DOT, BLOCK }

var _entries: Array[Dictionary] = []
var _settings: Dictionary = {}


func _ready() -> void:
	z_index = CombatConstants.Z_ARC + 1
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_settings[Style.NORMAL] = _make_settings(FeelConstants.DAMAGE_NUMBER_FONT_SIZE)
	_settings[Style.CRIT] = _make_settings(FeelConstants.DAMAGE_NUMBER_CRIT_FONT_SIZE)
	_settings[Style.DOT] = _make_settings(FeelConstants.DAMAGE_NUMBER_DOT_FONT_SIZE)
	_settings[Style.BLOCK] = _settings[Style.DOT]
	for i: int in FeelConstants.DAMAGE_NUMBER_POOL:
		var label: Label = Label.new()
		label.visible = false
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(label)
		_entries.append({"label": label, "active": false, "age": 0.0, "velocity": Vector2.ZERO, "key": "", "amount": 0, "style": Style.NORMAL})
	EventBus.damage_dealt.connect(_on_damage_dealt)
	EventBus.damage_blocked.connect(_on_damage_blocked)
	EventBus.enemy_dot_ticked.connect(_on_dot_ticked)
	set_process(false)


func _make_settings(font_size: int) -> LabelSettings:
	var settings: LabelSettings = LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = Color.WHITE
	settings.outline_size = 3
	settings.outline_color = Color.BLACK
	return settings


func _process(delta: float) -> void:
	var any: bool = false
	for entry: Dictionary in _entries:
		if not entry["active"]:
			continue
		any = true
		var label: Label = entry["label"]
		var age: float = float(entry["age"]) + delta
		entry["age"] = age
		var vel: Vector2 = entry["velocity"]
		vel.y += FeelConstants.DAMAGE_NUMBER_GRAVITY * delta
		entry["velocity"] = vel
		label.position += vel * delta
		var life: float = FeelConstants.DAMAGE_NUMBER_LIFETIME
		if int(entry["style"]) == Style.CRIT:
			label.scale = Vector2.ONE * lerpf(1.8, 1.0, clampf(age / 0.12, 0.0, 1.0))
		var fade_start: float = life * 0.55
		label.modulate.a = 1.0 if age < fade_start else clampf(1.0 - (age - fade_start) / (life - fade_start), 0.0, 1.0)
		if age >= life:
			entry["active"] = false
			label.visible = false
	if not any:
		set_process(false)


## Shows a number/text at "world_position" with the given style and color.
func show_text(world_position: Vector2, text_value: String, style: Style, color: Color, key: String = "") -> void:
	var entry: Dictionary = _take_entry()
	var label: Label = entry["label"]
	label.label_settings = _settings[style]
	label.text = text_value
	label.modulate = color
	label.size = label.get_minimum_size()
	label.pivot_offset = label.size * 0.5
	label.scale = Vector2.ONE
	label.position = world_position - label.size * 0.5 + Vector2(randf_range(-4.0, 4.0), 0.0)
	label.visible = true
	var rise: float = FeelConstants.DAMAGE_NUMBER_RISE * (0.6 if style == Style.DOT else 1.0)
	entry["velocity"] = Vector2(randf_range(-FeelConstants.DAMAGE_NUMBER_SPREAD, FeelConstants.DAMAGE_NUMBER_SPREAD), -rise)
	entry["age"] = 0.0
	entry["active"] = true
	entry["key"] = key
	entry["style"] = style
	set_process(true)


# Free entry of the pool; if all are in use, reuses the oldest
func _take_entry() -> Dictionary:
	var oldest: Dictionary = _entries[0]
	for entry: Dictionary in _entries:
		if not entry["active"]:
			return entry
		if float(entry["age"]) > float(oldest["age"]):
			oldest = entry
	return oldest


func _on_damage_dealt(world_position: Vector2, amount: int, is_crit: bool, color: Color) -> void:
	if is_crit:
		show_text(world_position, "%d!" % amount, Style.CRIT, color)
	else:
		show_text(world_position, str(amount), Style.NORMAL, color)


func _on_damage_blocked(world_position: Vector2) -> void:
	show_text(world_position, "BLOCK", Style.BLOCK, FeelConstants.DAMAGE_NUMBER_BLOCK_COLOR)


# DoT: adds to the still-visible number of the same enemy and source; otherwise creates a new one
func _on_dot_ticked(enemy: Node, source: StringName, amount: int) -> void:
	if amount <= 0 or not is_instance_valid(enemy):
		return
	var key: String = "%d:%s" % [enemy.get_instance_id(), source]
	for entry: Dictionary in _entries:
		if entry["active"] and entry["key"] == key and float(entry["age"]) < FeelConstants.DOT_GROUP_WINDOW:
			entry["amount"] = int(entry["amount"]) + amount
			var label: Label = entry["label"]
			label.text = str(entry["amount"])
			label.size = label.get_minimum_size()
			entry["age"] = 0.0
			label.modulate.a = 1.0
			return
	var feedback: HitFeedback = enemy.get_node_or_null("HitFeedback") as HitFeedback
	var at: Vector2 = feedback.head_position() if feedback != null else (enemy as Node2D).global_position + Vector2(0.0, -24.0)
	var color: Color = FeelConstants.DOT_COLORS.get(source, Color(0.45, 1.0, 0.35))
	show_text(at + Vector2(6.0, 4.0), str(amount), Style.DOT, color, key)
	for entry: Dictionary in _entries:
		if entry["key"] == key and entry["active"]:
			entry["amount"] = amount
			break
