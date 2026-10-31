class_name DungeonHud
extends CanvasLayer
## Textos do dungeon: cemitério atual, contagem regressiva da sala de horda (pulsa e fica vermelha no fim)
## e o aviso "SALA LIMPA" com flash suave quando uma sala é limpa.

const CLEAR_COLOR: Color = Color(1.0, 0.9, 0.55)
const TIMER_COLOR: Color = Color.WHITE
const TIMER_WARNING_COLOR: Color = Color(1.0, 0.25, 0.25)

var _label_cemetery: Label
var _label_timer: Label


func _ready() -> void:
	_label_cemetery = _make_label(Vector2(8.0, 40.0))
	_label_timer = _make_label(Vector2(260.0, 8.0))
	_label_timer.visible = false
	EventBus.cemetery_changed.connect(_on_cemetery_changed)
	EventBus.horde_timer_changed.connect(_on_horde_timer_changed)
	EventBus.room_cleared.connect(_on_room_cleared)


func _make_label(pos: Vector2) -> Label:
	var label: Label = Label.new()
	label.position = pos
	add_child(label)
	return label


# Mostra o cemitério atual e, no modo infinito, o loop
func _on_cemetery_changed(index: int, total: int) -> void:
	_label_cemetery.text = tr("Cemitério %d/%d") % [index, total]
	if GameManager.loop_index > 0:
		_label_cemetery.text += "  " + tr("Loop %d") % (GameManager.loop_index + 1)


# Valor negativo esconde o timer; nos últimos segundos o texto pulsa a cada segundo e fica vermelho
func _on_horde_timer_changed(seconds_left: float) -> void:
	_label_timer.visible = seconds_left >= 0.0
	_label_timer.text = "Horda: %.1fs" % seconds_left
	_label_timer.pivot_offset = _label_timer.size * 0.5
	if seconds_left >= 0.0 and seconds_left <= FeelConstants.HORDE_WARNING_SECONDS:
		var beat: float = 1.0 - fmod(seconds_left, 1.0)
		var pop: float = 1.0 + 0.3 * pow(1.0 - beat, 3.0)
		_label_timer.scale = Vector2.ONE * pop
		_label_timer.modulate = TIMER_WARNING_COLOR
	else:
		_label_timer.scale = Vector2.ONE
		_label_timer.modulate = TIMER_COLOR


# Flash suave na tela e "SALA LIMPA" subindo e sumindo
func _on_room_cleared() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size
	var flash: ColorRect = ColorRect.new()
	flash.color = Color(1.0, 1.0, 1.0, 0.18)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.size = screen
	add_child(flash)
	var flash_tween: Tween = flash.create_tween()
	flash_tween.tween_property(flash, "color:a", 0.0, 0.35)
	flash_tween.tween_callback(flash.queue_free)

	var label: Label = Label.new()
	label.text = tr("SALA LIMPA")
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", 22)
	label.add_theme_color_override("font_color", CLEAR_COLOR)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	label.size = label.get_minimum_size()
	label.pivot_offset = label.size * 0.5
	var start: Vector2 = Vector2((screen.x - label.size.x) * 0.5, screen.y * 0.35)
	label.position = start
	label.scale = Vector2.ONE * 1.6
	var tween: Tween = label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.5)
	tween.tween_property(label, "position:y", start.y - 30.0, 0.6).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.6)
	tween.tween_callback(label.queue_free)
