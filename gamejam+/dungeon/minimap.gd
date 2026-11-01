class_name Minimap
extends CanvasLayer
## Graveyard minimap: a single screenshot of the whole graveyard (taken once, when the level is built).
## Rooms not yet discovered stay black; a corridor shows up as soon as one of its rooms is visited.

@export var panel_size: Vector2 = Vector2(128.0, 96.0)
@export var margin: float = 8.0
@export var background_color: Color = Color(0.0, 0.0, 0.0, 1.0)
@export var border_color: Color = Color(1.0, 1.0, 1.0, 0.5)
@export var player_color: Color = Color(1.0, 1.0, 1.0)
## World px around the rooms that are also captured (walls, fences and corridors that loop outside the rooms)
@export var capture_margin: float = 200.0
## World px around each discovered room that are revealed together with it (walls and fences)
@export var reveal_padding: float = 40.0
## Largest side (px) of the captured image
@export var capture_max_side: int = 768

var _rooms: Array[RoomData] = []
var _corridors: Dictionary = {}
var _player: Node2D = null
var _canvas: Control = null
var _texture: ImageTexture = null
# World rectangle covered by the screenshot and its scale (texture px per world px)
var _bounds: Rect2 = Rect2()
var _capture_scale: float = 1.0


## Connects the minimap to the generated rooms, the corridors (Vector2i pair -> Array[Rect2]) and the player, then takes the screenshot.
func setup(rooms: Array[RoomData], player: Node2D, corridors: Dictionary = {}) -> void:
	_rooms = rooms
	_player = player
	_corridors = corridors
	_capture.call_deferred()


func _ready() -> void:
	layer = 5
	_canvas = Control.new()
	_canvas.custom_minimum_size = panel_size
	_canvas.size = panel_size
	_canvas.clip_contents = true
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
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


## Renders the whole graveyard once into a texture with a temporary SubViewport that shares the world.
## The player is hidden during the capture so the screenshot only has the scenery.
func _capture() -> void:
	if _rooms.is_empty() or DisplayServer.get_name() == "headless":
		return
	var area: Rect2 = _rooms[0].rect
	for room: RoomData in _rooms:
		area = area.merge(room.rect)
	_bounds = area.grow(capture_margin)
	_capture_scale = minf(float(capture_max_side) / _bounds.size.x, float(capture_max_side) / _bounds.size.y)
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i((_bounds.size * _capture_scale).ceil())
	view.world_2d = get_viewport().world_2d
	view.transparent_bg = false
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	var camera: Camera2D = Camera2D.new()
	camera.zoom = Vector2.ONE * _capture_scale
	camera.position = _bounds.get_center()
	view.add_child(camera)
	var player_was_visible: bool = _player != null and _player.visible
	if _player != null:
		_player.visible = false
	add_child(view)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = view.get_texture().get_image()
	if _player != null and is_instance_valid(_player):
		_player.visible = player_was_visible
	view.queue_free()
	if image == null or image.is_empty():
		return
	image.generate_mipmaps()
	_texture = ImageTexture.create_from_image(image)
	print("[Minimap] - screenshot of the graveyard taken (%dx%d)" % [image.get_width(), image.get_height()])


## Scale (panel px per world px) that fits the whole screenshot in the panel, and the offset that centers it.
func _fit() -> Dictionary:
	var fit_scale: float = minf(panel_size.x / _bounds.size.x, panel_size.y / _bounds.size.y)
	return {"scale": fit_scale, "offset": (panel_size - _bounds.size * fit_scale) * 0.5}


func _draw_map() -> void:
	_canvas.draw_rect(Rect2(Vector2.ZERO, panel_size), background_color)
	if _texture != null and _player != null:
		var fit: Dictionary = _fit()
		for i: int in _rooms.size():
			var room: RoomData = _rooms[i]
			if room.visited:
				_reveal(room.rect.grow(reveal_padding), fit)
			for neighbor: int in room.neighbors.values():
				if neighbor > i and (room.visited or _rooms[neighbor].visited):
					for piece: Rect2 in _corridors.get(Vector2i(i, neighbor), []):
						_reveal(piece.grow(reveal_padding * 0.5), fit)
		var marker: Vector2 = _to_panel(_player.global_position, fit)
		_canvas.draw_circle(marker, 2.5, Color(0.0, 0.0, 0.0, 0.8))
		_canvas.draw_circle(marker, 1.8, player_color)
	_canvas.draw_rect(Rect2(Vector2.ZERO, panel_size), border_color, false, 1.0)


## Draws the part of the screenshot that covers a world rectangle.
func _reveal(world_rect: Rect2, fit: Dictionary) -> void:
	var clipped: Rect2 = world_rect.intersection(_bounds)
	if clipped.size.x <= 0.0 or clipped.size.y <= 0.0:
		return
	var source: Rect2 = Rect2((clipped.position - _bounds.position) * _capture_scale, clipped.size * _capture_scale)
	var target: Rect2 = Rect2(_to_panel(clipped.position, fit), clipped.size * float(fit["scale"]))
	_canvas.draw_texture_rect_region(_texture, target, source)


func _to_panel(world: Vector2, fit: Dictionary) -> Vector2:
	return Vector2(fit["offset"]) + (world - _bounds.position) * float(fit["scale"])
