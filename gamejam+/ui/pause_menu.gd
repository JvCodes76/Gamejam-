extends CanvasLayer
## Pause menu: shows and hides according to EventBus.game_paused.

@onready var _botao_continuar: Button = $Painel/VBox/BotaoContinuar
@onready var _botao_config: Button = $Painel/VBox/BotaoConfig
@onready var _botao_menu: Button = $Painel/VBox/BotaoMenu

var _settings: CanvasLayer


func _ready() -> void:
	visible = false
	EventBus.game_paused.connect(_on_game_paused)
	_botao_continuar.pressed.connect(_on_continuar_pressed)
	_botao_menu.pressed.connect(_on_menu_pressed)
	_settings = preload("res://ui/settings_menu.tscn").instantiate()
	add_child(_settings)
	_botao_config.pressed.connect(_settings.open)
	_build_shake_toggle()
	for button: BaseButton in [_botao_continuar, _botao_config, _botao_menu]:
		_add_ui_sounds(button)
	print("[UI] - Pause menu ready")


# Accessibility: "Reduce screen shake" option (GameManager.reduce_screen_shake)
func _build_shake_toggle() -> void:
	var toggle: CheckButton = CheckButton.new()
	toggle.name = "ReduzirTremida"
	toggle.text = tr("Reduce screen shake")
	toggle.button_pressed = GameManager.reduce_screen_shake
	toggle.toggled.connect(_on_reduce_shake_toggled)
	var vbox: VBoxContainer = $Painel/VBox as VBoxContainer
	vbox.add_child(toggle)
	vbox.move_child(toggle, _botao_menu.get_index())
	_add_ui_sounds(toggle)


func _add_ui_sounds(button: BaseButton) -> void:
	button.mouse_entered.connect(EventBus.play_sfx_requested.emit.bind("ui_hover"))
	button.pressed.connect(EventBus.play_sfx_requested.emit.bind("ui_click"))


func _on_reduce_shake_toggled(enabled: bool) -> void:
	GameManager.reduce_screen_shake = enabled
	print("[UI] - Reduce shake: %s" % str(enabled))


# Handles the "pause" action (Esc / Start) to toggle the pause
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not ItemManager.inventory_open and not _settings.visible:
		GameManager.toggle_pause()
		get_viewport().set_input_as_handled()


# Shows or hides the panel according to the pause state
func _on_game_paused(paused: bool) -> void:
	visible = paused
	print("[UI] - Paused: %s" % str(paused))


# Resumes the game
func _on_continuar_pressed() -> void:
	print("[UI] - Resume pressed")
	GameManager.toggle_pause()


# Returns to the main menu
func _on_menu_pressed() -> void:
	print("[UI] - Main menu pressed")
	GameManager.quit_to_menu()
