extends Control
## Main menu: Play and Quit buttons.

@onready var _botao_jogar: Button = $VBox/BotaoJogar
@onready var _botao_sair: Button = $VBox/BotaoSair


func _ready() -> void:
	# Connects the menu buttons
	_botao_jogar.pressed.connect(_on_jogar_pressed)
	_botao_sair.pressed.connect(_on_sair_pressed)
	for button: Button in [_botao_jogar, _botao_sair]:
		button.mouse_entered.connect(EventBus.play_sfx_requested.emit.bind("ui_hover"))
		button.pressed.connect(EventBus.play_sfx_requested.emit.bind("ui_click"))
	print("[UI] - Main menu ready")


# Starts the game through the GameManager
func _on_jogar_pressed() -> void:
	print("[UI] - Play pressed")
	GameManager.start_game()


# Closes the game
func _on_sair_pressed() -> void:
	print("[UI] - Quit pressed")
	get_tree().quit()
