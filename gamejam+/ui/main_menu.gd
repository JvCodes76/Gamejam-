extends Control
## Main menu: Play and Quit buttons.

@onready var _botao_jogar: Button = $VBox/BotaoJogar
@onready var _botao_survivors: Button = $VBox/BotaoSurvivors
@onready var _botao_tutorial: Button = $VBox/BotaoTutorial
@onready var _botao_config: Button = $VBox/BotaoConfig
@onready var _botao_sair: Button = $VBox/BotaoSair

var _settings: CanvasLayer


func _ready() -> void:
	_settings = preload("res://ui/settings_menu.tscn").instantiate()
	add_child(_settings)
	_botao_config.pressed.connect(_on_config_pressed)
	# Connects the menu buttons
	_botao_jogar.pressed.connect(_on_jogar_pressed)
	_botao_survivors.pressed.connect(_on_survivors_pressed)
	_botao_tutorial.pressed.connect(_on_tutorial_pressed)
	_botao_sair.pressed.connect(_on_sair_pressed)
	for button: Button in [_botao_jogar, _botao_survivors, _botao_tutorial, _botao_config, _botao_sair]:
		button.mouse_entered.connect(EventBus.play_sfx_requested.emit.bind("ui_hover"))
		button.pressed.connect(EventBus.play_sfx_requested.emit.bind("ui_click"))
	print("[UI] - Main menu ready")


# Starts the game through the GameManager
func _on_jogar_pressed() -> void:
	print("[UI] - Play pressed")
	GameManager.start_game()


# Starts the Monster Survivors mode
func _on_survivors_pressed() -> void:
	print("[UI] - Monster Survivors pressed")
	GameManager.start_game(false, true)


# Starts the tutorial
func _on_tutorial_pressed() -> void:
	print("[UI] - Tutorial pressed")
	GameManager.start_game(true)


# Opens the settings screen
func _on_config_pressed() -> void:
	print("[UI] - Settings pressed")
	_settings.open()


# Closes the game
func _on_sair_pressed() -> void:
	print("[UI] - Quit pressed")
	get_tree().quit()
