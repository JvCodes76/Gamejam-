extends CanvasLayer
## HUD: mostra vida e pontuacao, atualizadas pelos sinais do EventBus.

@onready var _label_vida: Label = $LabelVida
@onready var _label_pontos: Label = $LabelPontos

@onready var _label_rage: Label = $LabelRage
@onready var _slots: Array[PotionSlot] = [$PotionSlot1, $PotionSlot2]


func _ready() -> void:
	EventBus.potion_slots_changed.connect(_refresh_potions)
	EventBus.potion_selected.connect(_on_potion_selected)
	_refresh_potions()
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.score_changed.connect(_on_score_changed)
	EventBus.rage_changed.connect(_on_rage_changed)
	_label_pontos.text = "Pontos: %d" % GameManager.score
	print("[UI] - HUD pronto")


# Atualiza o texto de vida
func _on_player_health_changed(current: int, max_value: int) -> void:
	_label_vida.text = "Vida: %d/%d" % [current, max_value]


# Mostra a raiva (sinergia Evil) só quando maior que zero
func _on_rage_changed(bonus: float) -> void:
	_label_rage.visible = bonus > 0.0
	_label_rage.text = "Rage +%.1f%%" % (bonus * 100.0)


# Atualiza o texto de pontuacao
func _on_score_changed(score: int) -> void:
	_label_pontos.text = "Pontos: %d" % score


# Atualiza os frascos ao trocar o slot ativo
func _on_potion_selected(_index: int) -> void:
	_refresh_potions()


# Redesenha os dois frascos conforme os slots do ItemManager
func _refresh_potions() -> void:
	for i: int in _slots.size():
		var potion: PotionData = ItemManager.potion_slots[i]
		var color: Color = potion.color if potion != null else Color.WHITE
		_slots[i].set_state(potion != null, color, i == ItemManager.active_potion_index)
