extends Control
## Main menu: Play and Quit buttons.

@onready var _botao_jogar: Button = $VBox/BotaoJogar
@onready var _botao_survivors: Button = $VBox/BotaoSurvivors
@onready var _botao_tutorial: Button = $VBox/BotaoTutorial
@onready var _botao_config: Button = $VBox/BotaoConfig
@onready var _botao_sair: Button = $VBox/BotaoSair

const BOB_AMPLITUDE: float = 5.0  # Pixels
const BOB_SPEED: float = 1.3  # Radians per second

var _settings: CanvasLayer
var _bob_root: Control  # Wrapper around the VBox: moving a parent keeps children on integer local positions
var _bob_time: float = 0.0


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
	# Wraps the VBox in a full-rect Control and bobs that: the offset becomes a smooth canvas translation
	# (moving each child by fractional positions makes the text snap to whole pixels, which looks choppy)
	_bob_root = Control.new()
	_bob_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bob_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: Control = $VBox
	remove_child(box)
	_bob_root.add_child(box)
	add_child(_bob_root)
	print("[UI] - Main menu ready")


func _process(delta: float) -> void:
	_bob_time += delta
	# Same offset for the whole block, so the logo and buttons move together as one
	_bob_root.position = Vector2(0.0, sin(_bob_time * BOB_SPEED) * BOB_AMPLITUDE)


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
