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
var _bob_bases: Dictionary = {}  # Control -> position decided by the container
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
	# The container owns the children's positions: record them after each sort and bob on top of that
	$VBox.sort_children.connect(_record_bob_bases)
	_record_bob_bases()
	print("[UI] - Main menu ready")


func _process(delta: float) -> void:
	_bob_time += delta
	# Same offset for every element, so the logo and buttons move together as a single block
	var offset: Vector2 = Vector2(0.0, sin(_bob_time * BOB_SPEED) * BOB_AMPLITUDE)
	for child: Control in _bob_bases:
		child.position = _bob_bases[child] + offset


func _record_bob_bases() -> void:
	_bob_bases.clear()
	for child: Node in $VBox.get_children():
		if child is Control:
			_bob_bases[child] = child.position


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
