class_name Minimap
extends CanvasLayer
## Minimapa do cemitério: só as salas já visitadas, em blocos chapados (sem tiles nem props), centrado no player.

@export var panel_size: Vector2 = Vector2(180.0, 140.0)
@export var margin: float = 8.0
## Pixels de mapa por pixel de mundo (menor = mais zoom out)
@export var map_scale: float = 0.06
@export var background_color: Color = Color(0.0, 0.0, 0.0, 0.6)
@export var border_color: Color = Color(1.0, 1.0, 1.0, 0.5)
@export var room_alpha: float = 0.55
@export var corridor_color: Color = Color(1.0, 1.0, 1.0, 0.35)
@export var corridor_width: float = 3.0
@export var player_color: Color = Color(1.0, 1.0, 1.0)

var _rooms: Array[RoomData] = []
var _player: Node2D = null
var _canvas: Control = null


## Liga o minimapa às salas geradas e ao player.
func setup(rooms: Array[RoomData], player: Node2D) -> void:
	_rooms = rooms
	_player = player


func _ready() -> void:
	layer = 5
	_canvas = Control.new()
	_canvas.custom_minimum_size = panel_size
	_canvas.size = panel_size
	_canvas.clip_contents = true
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_canvas.offset_right = -margin
	_canvas.offset_left = -margin - panel_size.x
	_canvas.offset_top = margin
	_canvas.offset_bottom = margin + panel_size.y
	_canvas.draw.connect(_draw_map)
	add_child(_canvas)


func _process(_delta: float) -> void:
	if _canvas != null:
		_canvas.queue_redraw()


## Converte uma posição do mundo para o painel (player no centro).
func _to_panel(world: Vector2) -> Vector2:
	return panel_size / 2.0 + (world - _player.global_position) * map_scale


func _draw_map() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, panel_size), background_color)
	if _player != null:
		# Corredores só entre salas visitadas (não revela as vizinhas)
		for i: int in _rooms.size():
			var room: RoomData = _rooms[i]
			if not room.visited:
				continue
			for neighbor: int in room.neighbors.values():
				if neighbor > i and _rooms[neighbor].visited:
					_canvas.draw_line(_to_panel(room.center()), _to_panel(_rooms[neighbor].center()), corridor_color, corridor_width)
		for room: RoomData in _rooms:
			if not room.visited:
				continue
			var rect: Rect2 = Rect2(_to_panel(room.rect.position), room.rect.size * map_scale)
			var color: Color = RoomData.DEBUG_COLORS[room.type]
			_canvas.draw_rect(rect, Color(color, room_alpha))
			_canvas.draw_rect(rect, Color(color, 1.0), false, 1.0)
		_canvas.draw_circle(panel_size / 2.0, 2.5, player_color)
	_canvas.draw_rect(Rect2(Vector2.ZERO, panel_size), border_color, false, 1.0)
