class_name RunSummary
extends CanvasLayer
## Run summary: appears on EventBus.run_ended. On defeat it only allows going back to the menu;
## on victory (boss defeated) it allows ending the run or continuing in infinite mode.

const VICTORY_COLOR: Color = Color(1.0, 0.85, 0.4)
const DEFEAT_COLOR: Color = Color(1.0, 0.35, 0.35)
const LABEL_COLOR: Color = Color(0.75, 0.75, 0.8)

## Duration (s) of the logo + panel fade-in
@export var fade_in_time: float = 0.35

@onready var _conteudo: HBoxContainer = $Conteudo
@onready var _titulo: Label = $Conteudo/Painel/VBox/Titulo
@onready var _subtitulo: Label = $Conteudo/Painel/VBox/Subtitulo
@onready var _stats: GridContainer = $Conteudo/Painel/VBox/Stats
@onready var _itens: Label = $Conteudo/Painel/VBox/Itens
@onready var _botao_continuar: Button = $Conteudo/Painel/VBox/Botoes/BotaoContinuar
@onready var _botao_menu: Button = $Conteudo/Painel/VBox/Botoes/BotaoMenu


func _ready() -> void:
	visible = false
	EventBus.run_ended.connect(_on_run_ended)
	_botao_continuar.pressed.connect(_on_continuar_pressed)
	_botao_menu.pressed.connect(_on_menu_pressed)
	for button: Button in [_botao_continuar, _botao_menu]:
		button.mouse_entered.connect(EventBus.play_sfx_requested.emit.bind("ui_hover"))
		button.pressed.connect(EventBus.play_sfx_requested.emit.bind("ui_click"))


# Fills in and shows the summary (the GameManager has already paused the tree)
func _on_run_ended(victory: bool) -> void:
	_fill(victory)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_conteudo.modulate.a = 0.0
	var tween: Tween = create_tween()
	tween.tween_property(_conteudo, "modulate:a", 1.0, fade_in_time)
	if victory:
		_botao_continuar.grab_focus()
	else:
		_botao_menu.grab_focus()
	print("[UI] - Run summary (victory: %s)" % str(victory))


# Title, run statistics and buttons according to the result
func _fill(victory: bool) -> void:
	var loop: int = GameManager.loop_index + 1
	_titulo.text = tr("VICTORY") if victory else tr("YOU DIED")
	_titulo.add_theme_color_override("font_color", VICTORY_COLOR if victory else DEFEAT_COLOR)
	if victory:
		_subtitulo.text = tr("The guardian of the last graveyard has fallen. Loop %d complete.") % loop
	else:
		_subtitulo.text = tr("Fell in graveyard %d of loop %d.") % [GameManager.cemetery_index, loop]

	for child: Node in _stats.get_children():
		child.queue_free()
	_add_stat(tr("Score"), str(GameManager.score))
	_add_stat(tr("Time"), _format_time(GameManager.run_time))
	_add_stat(tr("Loop"), str(loop))
	_add_stat(tr("Rooms visited"), str(GameManager.rooms_visited))
	_add_stat(tr("Enemies defeated"), str(GameManager.kills))
	_add_stat(tr("Elites defeated"), str(GameManager.elite_kills))
	_add_stat(tr("Bosses defeated"), str(GameManager.bosses_defeated))
	_add_stat(tr("Potions brewed"), str(GameManager.potions_brewed))
	_add_stat(tr("Items collected"), str(GameManager.items_collected))

	var names: PackedStringArray = _bag_item_names()
	_itens.text = tr("Bag: %s") % (", ".join(names) if not names.is_empty() else tr("empty"))

	_botao_continuar.visible = victory
	_botao_continuar.text = tr("Continue (Loop %d)") % (loop + 1)
	_botao_menu.text = tr("End run") if victory else tr("Main menu")


# "name  value" row in the statistics grid
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


# Names of the items in the bag at the end of the run
func _bag_item_names() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for entry: Dictionary in ItemManager.bag_entries:
		var item: ItemData = entry.get("item") as ItemData
		if item != null:
			names.append(item.display_name if item.display_name != "" else String(item.id))
	return names


# Seconds as mm:ss (or h:mm:ss in long infinite mode runs)
func _format_time(seconds: float) -> String:
	var total: int = int(seconds)
	var h: int = floori(total / 3600.0)
	var m: int = floori((total % 3600) / 60.0)
	var s: int = total % 60
	if h > 0:
		return "%d:%02d:%02d" % [h, m, s]
	return "%02d:%02d" % [m, s]


# Infinite mode: goes back to the first graveyard with items kept
func _on_continuar_pressed() -> void:
	print("[UI] - Continue in infinite mode pressed")
	visible = false
	GameManager.continue_endless()


# Ends the run and returns to the main menu
func _on_menu_pressed() -> void:
	print("[UI] - End run pressed")
	GameManager.quit_to_menu()
