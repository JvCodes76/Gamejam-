extends CanvasLayer
## Menu de pausa: aparece e some conforme EventBus.game_paused.

@onready var _botao_continuar: Button = $Painel/VBox/BotaoContinuar
@onready var _botao_menu: Button = $Painel/VBox/BotaoMenu


func _ready() -> void:
	visible = false
	EventBus.game_paused.connect(_on_game_paused)
	_botao_continuar.pressed.connect(_on_continuar_pressed)
	_botao_menu.pressed.connect(_on_menu_pressed)
	_build_shake_toggle()
	for button: BaseButton in [_botao_continuar, _botao_menu]:
		_add_ui_sounds(button)
	print("[UI] - Pause menu pronto")


# Acessibilidade: opção "Reduzir tremida de tela" (GameManager.reduce_screen_shake)
func _build_shake_toggle() -> void:
	var toggle: CheckButton = CheckButton.new()
	toggle.name = "ReduzirTremida"
	toggle.text = tr("Reduzir tremida de tela")
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
	print("[UI] - Reduzir tremida: %s" % str(enabled))


# Trata a acao "pause" (Esc / Start) para alternar a pausa
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and not ItemManager.inventory_open:
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
