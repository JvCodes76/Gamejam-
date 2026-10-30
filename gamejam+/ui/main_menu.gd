extends Control
## Menu principal: botoes Jogar e Sair.

@onready var _botao_jogar: Button = $VBox/BotaoJogar
@onready var _botao_sair: Button = $VBox/BotaoSair


func _ready() -> void:
	# Conecta os botoes do menu
	_botao_jogar.pressed.connect(_on_jogar_pressed)
	_botao_sair.pressed.connect(_on_sair_pressed)
	print("[UI] - Menu principal pronto")


# Inicia o jogo pelo GameManager
func _on_jogar_pressed() -> void:
	print("[UI] - Jogar pressionado")
	GameManager.start_game()


# Fecha o jogo
func _on_sair_pressed() -> void:
	print("[UI] - Sair pressionado")
	get_tree().quit()
