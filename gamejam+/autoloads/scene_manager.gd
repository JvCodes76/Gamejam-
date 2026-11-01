extends CanvasLayer

@export var fade_duration: float = 0.25

var _rect: ColorRect
var _changing: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_rect = ColorRect.new()
	_rect.color = Color.BLACK
	_rect.modulate.a = 0.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)
	EventBus.scene_change_requested.connect(change_scene)


## Scene change with fade out/in. Ignores requests during a change.
func change_scene(path: String) -> void:
	if _changing:
		return
	_changing = true
	var tween: Tween = create_tween()
	tween.tween_property(_rect, "modulate:a", 1.0, fade_duration)
	await tween.finished
	var err: Error = get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("[Scene] - failed to load %s (error %d)" % [path, err])
		_rect.modulate.a = 0.0
		_changing = false
		return
	tween = create_tween()
	tween.tween_property(_rect, "modulate:a", 0.0, fade_duration)
	await tween.finished
	_changing = false
