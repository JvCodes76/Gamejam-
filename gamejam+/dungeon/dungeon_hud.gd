class_name DungeonHud
extends CanvasLayer
## Textos do dungeon: cemitério atual e contagem regressiva da sala de horda.

var _label_cemetery: Label
var _label_timer: Label


func _ready() -> void:
	_label_cemetery = _make_label(Vector2(8.0, 40.0))
	_label_timer = _make_label(Vector2(260.0, 8.0))
	_label_timer.visible = false
	EventBus.cemetery_changed.connect(_on_cemetery_changed)
	EventBus.horde_timer_changed.connect(_on_horde_timer_changed)


func _make_label(pos: Vector2) -> Label:
	var label: Label = Label.new()
	label.position = pos
	add_child(label)
	return label


func _on_cemetery_changed(index: int, total: int) -> void:
	_label_cemetery.text = "Cemitério %d/%d" % [index, total]


# Valor negativo esconde o timer
func _on_horde_timer_changed(seconds_left: float) -> void:
	_label_timer.visible = seconds_left >= 0.0
	_label_timer.text = "Horda: %.1fs" % seconds_left
