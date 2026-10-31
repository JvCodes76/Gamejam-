class_name RunSummary
extends CanvasLayer
## Sumário da run: aparece em EventBus.run_ended. Na derrota só permite voltar ao menu;
## na vitória (boss derrotado) permite encerrar a run ou continuar no modo infinito.

const VICTORY_COLOR: Color = Color(1.0, 0.85, 0.4)
const DEFEAT_COLOR: Color = Color(1.0, 0.35, 0.35)
const LABEL_COLOR: Color = Color(0.75, 0.75, 0.8)

## Duração (s) do fade-in do painel
@export var fade_in_time: float = 0.35

@onready var _painel: PanelContainer = $Painel
@onready var _titulo: Label = $Painel/VBox/Titulo
@onready var _subtitulo: Label = $Painel/VBox/Subtitulo
@onready var _stats: GridContainer = $Painel/VBox/Stats
@onready var _itens: Label = $Painel/VBox/Itens
@onready var _botao_continuar: Button = $Painel/VBox/Botoes/BotaoContinuar
@onready var _botao_menu: Button = $Painel/VBox/Botoes/BotaoMenu


func _ready() -> void:
	visible = false
	EventBus.run_ended.connect(_on_run_ended)
	_botao_continuar.pressed.connect(_on_continuar_pressed)
	_botao_menu.pressed.connect(_on_menu_pressed)
	for button: Button in [_botao_continuar, _botao_menu]:
		button.mouse_entered.connect(EventBus.play_sfx_requested.emit.bind("ui_hover"))
		button.pressed.connect(EventBus.play_sfx_requested.emit.bind("ui_click"))


# Preenche e mostra o sumário (o GameManager já pausou a árvore)
func _on_run_ended(victory: bool) -> void:
	_fill(victory)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_painel.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(_painel, "modulate:a", 1.0, fade_in_time)
	if victory:
		_botao_continuar.grab_focus()
	else:
		_botao_menu.grab_focus()
	print("[UI] - Sumário da run (vitória: %s)" % str(victory))


# Título, estatísticas da run e botões conforme o resultado
func _fill(victory: bool) -> void:
	var loop: int = GameManager.loop_index + 1
	_titulo.text = tr("VITÓRIA") if victory else tr("VOCÊ MORREU")
	_titulo.add_theme_color_override("font_color", VICTORY_COLOR if victory else DEFEAT_COLOR)
	if victory:
		_subtitulo.text = tr("O guardião do último cemitério caiu. Loop %d completo.") % loop
	else:
		_subtitulo.text = tr("Caiu no cemitério %d do loop %d.") % [GameManager.cemetery_index, loop]

	for child: Node in _stats.get_children():
		child.queue_free()
	_add_stat(tr("Pontos"), str(GameManager.score))
	_add_stat(tr("Tempo"), _format_time(GameManager.run_time))
	_add_stat(tr("Loop"), str(loop))
	_add_stat(tr("Salas visitadas"), str(GameManager.rooms_visited))
	_add_stat(tr("Inimigos derrotados"), str(GameManager.kills))
	_add_stat(tr("Elites derrotados"), str(GameManager.elite_kills))
	_add_stat(tr("Bosses derrotados"), str(GameManager.bosses_defeated))
	_add_stat(tr("Poções preparadas"), str(GameManager.potions_brewed))
	_add_stat(tr("Itens coletados"), str(GameManager.items_collected))

	var names: PackedStringArray = _bag_item_names()
	_itens.text = tr("Bolsa: %s") % (", ".join(names) if not names.is_empty() else tr("vazia"))

	_botao_continuar.visible = victory
	_botao_continuar.text = tr("Continuar (Loop %d)") % (loop + 1)
	_botao_menu.text = tr("Encerrar run") if victory else tr("Menu principal")


# Linha "nome  valor" na grade de estatísticas
func _add_stat(stat_name: String, value: String) -> void:
	var name_label: Label = Label.new()
	name_label.text = stat_name
	name_label.add_theme_color_override("font_color", LABEL_COLOR)
	_stats.add_child(name_label)
	var value_label: Label = Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats.add_child(value_label)


# Nomes dos itens que estão na bolsa ao fim da run
func _bag_item_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in ItemManager.bag_entries:
		var item: ItemData = entry.get("item") as ItemData
		if item != null:
			names.append(item.display_name if item.display_name != "" else String(item.id))
	return names


# Segundos em mm:ss (ou h:mm:ss em runs longas do modo infinito)
func _format_time(seconds: float) -> String:
	var total: int = int(seconds)
	var h: int = floori(total / 3600.0)
	var m: int = floori((total % 3600) / 60.0)
	var s: int = total % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%02d:%02d" % [m, s]


# Modo infinito: volta ao primeiro cemitério com os itens mantidos
func _on_continuar_pressed() -> void:
	print("[UI] - Continuar no modo infinito pressionado")
	visible = false
	GameManager.continue_endless()


# Encerra a run e volta ao menu principal
func _on_menu_pressed() -> void:
	print("[UI] - Encerrar run pressionado")
	GameManager.quit_to_menu()
