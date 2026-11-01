extends CanvasLayer
## HUD: health (drawn blocks), animated score, rage bar, potion flasks and damage vignette,
## updated by the EventBus signals.

@onready var _health_display: HealthDisplay = $HealthDisplay
@onready var _label_pontos: Label = $LabelPontos

@onready var _label_rage: Label = $LabelRage
@onready var _slots: Array[PotionSlot] = [$PotionSlot1, $PotionSlot2]

var _rage_bar: RageBar
var _shown_score: int = 0
var _score_tween: Tween
var _score_pop_tween: Tween


func _ready() -> void:
	var vignette: DamageVignette = DamageVignette.new()
	vignette.name = "DamageVignette"
	add_child(vignette)
	move_child(vignette, 0)
	_rage_bar = RageBar.new()
	_rage_bar.name = "RageBar"
	_rage_bar.position = Vector2(0.0, 22.0)
	_label_rage.add_child(_rage_bar)
	var journal: JournalUi = JournalUi.new()
	journal.name = "JournalUi"
	add_child(journal)
	var journal_button: JournalButton = JournalButton.new()
	journal_button.name = "JournalButton"
	add_child(journal_button)
	_add_debug_items_button()
	EventBus.potion_slots_changed.connect(_refresh_potions)
	EventBus.potion_selected.connect(_on_potion_selected)
	_refresh_potions()
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.rage_changed.connect(_on_rage_changed)
	_shown_score = GameManager.score
	_set_shown_score(_shown_score)
	print("[UI] - HUD ready")


# Updates the health blocks
func _on_player_health_changed(current: int, max_value: int) -> void:
	_health_display.set_health(current, max_value)


# Shows the rage (Evil synergy) only when greater than zero
func _on_rage_changed(bonus: float) -> void:
	_label_rage.visible = bonus > 0.0
	_label_rage.text = "Rage +%.1f%%" % (bonus * 100.0)
	_rage_bar.set_bonus(bonus)


# Counts up to the new score and gives the text a pop
func _on_score_changed(score: int) -> void:
	if _score_tween != null:
		_score_tween.kill()
	if score <= _shown_score:
		_set_shown_score(score)
		return
	_score_tween = create_tween()
	_score_tween.tween_method(_set_shown_score, _shown_score, score, 0.3)
	_label_pontos.pivot_offset = Vector2(0.0, _label_pontos.size.y * 0.5)
	if _score_pop_tween != null:
		_score_pop_tween.kill()
	_label_pontos.scale = Vector2.ONE * 1.3
	_score_pop_tween = create_tween()
	_score_pop_tween.tween_property(_label_pontos, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _set_shown_score(value: int) -> void:
	_shown_score = value
	_label_pontos.text = "Score: %d" % value


# Updates the flasks when the active slot changes
func _on_potion_selected(_index: int) -> void:
	_refresh_potions()
	EventBus.play_sfx_requested.emit("potion_swap")


# Redraws the two flasks according to the ItemManager slots
func _refresh_potions() -> void:
	for i: int in _slots.size():
		var potion: PotionData = ItemManager.potion_slots[i]
		var color: Color = potion.color if potion != null else Color.WHITE
		_slots[i].set_state(potion != null, color, i == ItemManager.active_potion_index)


# [DEBUG] Button that shrinks the items and drops every item in the game around the player
func _add_debug_items_button() -> void:
	var button: Button = Button.new()
	button.name = "DebugItemsButton"
	button.text = "[DEBUG] Drop all items"
	button.focus_mode = Control.FOCUS_NONE
	button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -170.0
	button.offset_right = -8.0
	button.offset_top = 8.0
	button.offset_bottom = 32.0
	button.pressed.connect(_on_debug_items_pressed)
	add_child(button)


# [DEBUG] Shrinks the items to the minimum and spreads all of them on the ground near the player
func _on_debug_items_pressed() -> void:
	ItemManager.optimize_bag(1000.0)
	var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
	var origin: Vector2 = player.global_position if player != null else Vector2.ZERO
	var items: Array[ItemData] = []
	var dir: DirAccess = DirAccess.open(LootManager.ITEMS_DIR)
	if dir == null:
		push_warning("[DEBUG] - items folder not found")
		return
	var files: PackedStringArray = dir.get_files()
	files.sort()
	for file: String in files:
		var clean: String = file.trim_suffix(".remap")
		if not clean.ends_with(".tres"):
			continue
		var item: ItemData = load(LootManager.ITEMS_DIR + clean) as ItemData
		if item != null and item.is_valid():
			items.append(item)
	var on_ground: Array[StringName] = []
	for entry: Dictionary in ItemManager.ground_entries:
		on_ground.append((entry["item"] as ItemData).id)
	var to_drop: Array[ItemData] = items.filter(func(i: ItemData) -> bool: return not on_ground.has(i.id))
	# Concentric rings around the player so the items do not overlap
	var ring: int = 0
	var slot: int = 0
	var per_ring: int = 8
	for item: ItemData in to_drop:
		var radius: float = 40.0 + 28.0 * ring
		var angle: float = TAU * float(slot) / float(per_ring) + ring * 0.4
		ItemManager.drop_to_ground(item, origin + Vector2.from_angle(angle) * radius)
		slot += 1
		if slot >= per_ring:
			slot = 0
			ring += 1
			per_ring += 6
	print("[DEBUG] - %d items dropped near the player (bag scale %.3f)" % [to_drop.size(), ItemManager.floor_scale()])
