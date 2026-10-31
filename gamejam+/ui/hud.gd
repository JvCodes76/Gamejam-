extends CanvasLayer
## HUD: vida (blocos desenhados), pontuação animada, barra de raiva, frascos de poção e vinheta de dano,
## atualizados pelos sinais do EventBus.

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
	EventBus.potion_slots_changed.connect(_refresh_potions)
	EventBus.potion_selected.connect(_on_potion_selected)
	_refresh_potions()
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.rage_changed.connect(_on_rage_changed)
	_shown_score = GameManager.score
	_set_shown_score(_shown_score)
	print("[UI] - HUD pronto")


# Atualiza os blocos de vida
func _on_player_health_changed(current: int, max_value: int) -> void:
	_health_display.set_health(current, max_value)


# Mostra a raiva (sinergia Evil) só quando maior que zero
func _on_rage_changed(bonus: float) -> void:
	_label_rage.visible = bonus > 0.0
	_label_rage.text = "Rage +%.1f%%" % (bonus * 100.0)
	_rage_bar.set_bonus(bonus)


# Conta até a nova pontuação e dá um pop no texto
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
	_label_pontos.text = "Pontos: %d" % value


# Atualiza os frascos ao trocar o slot ativo
func _on_potion_selected(_index: int) -> void:
	_refresh_potions()
	EventBus.play_sfx_requested.emit("potion_swap")


# Redesenha os dois frascos conforme os slots do ItemManager
func _refresh_potions() -> void:
	for i: int in _slots.size():
		var potion: PotionData = ItemManager.potion_slots[i]
		var color: Color = potion.color if potion != null else Color.WHITE
		_slots[i].set_state(potion != null, color, i == ItemManager.active_potion_index)
