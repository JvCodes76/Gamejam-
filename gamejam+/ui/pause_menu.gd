extends CanvasLayer
## Menu de pausa: aparece e some conforme EventBus.game_paused.

@onready var _botao_continuar: Button = $Painel/VBox/BotaoContinuar
@onready var _botao_menu: Button = $Painel/VBox/BotaoMenu


func _ready() -> void:
	visible = false
	EventBus.game_paused.connect(_on_game_paused)
	_botao_continuar.pressed.connect(_on_continuar_pressed)
	_botao_menu.pressed.connect(_on_menu_pressed)
	print("[UI] - Pause menu pronto")


# Trata a acao "pause" (Esc / Start) para alternar a pausa
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		GameManager.toggle_pause()
		get_viewport().set_input_as_handled()


# Mostra ou esconde o painel conforme o estado de pausa
func _on_game_paused(paused: bool) -> void:
	visible = paused
	print("[UI] - Pausado: %s" % str(paused))


# Retoma o jogo
func _on_continuar_pressed() -> void:
	print("[UI] - Continuar pressionado")
	GameManager.toggle_pause()


# Volta ao menu principal
func _on_menu_pressed() -> void:
	print("[UI] - Menu principal pressionado")
	GameManager.quit_to_menu()
