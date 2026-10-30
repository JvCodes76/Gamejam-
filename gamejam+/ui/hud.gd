extends CanvasLayer
## HUD: mostra vida e pontuacao, atualizadas pelos sinais do EventBus.

@onready var _label_vida: Label = $LabelVida
@onready var _label_pontos: Label = $LabelPontos


func _ready() -> void:
	EventBus.player_health_changed.connect(_on_player_health_changed)
	EventBus.score_changed.connect(_on_score_changed)
	_label_pontos.text = "Pontos: %d" % GameManager.score
	print("[UI] - HUD pronto")


# Atualiza o texto de vida
func _on_player_health_changed(current: int, max_value: int) -> void:
	_label_vida.text = "Vida: %d/%d" % [current, max_value]


# Atualiza o texto de pontuacao
func _on_score_changed(score: int) -> void:
	_label_pontos.text = "Pontos: %d" % score
