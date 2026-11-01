class_name AmmoIndicator
extends Node2D
## Magazine over the player's head (Gun): one pip per bullet, or a bar filling up while reloading.

const PIP_SIZE: Vector2 = Vector2(3.0, 5.0)
const PIP_GAP: float = 2.0
const BAR_WIDTH: float = 22.0

var ammo: int = 0
var capacity: int = 0
## Reload progress (0 to 1); negative when not reloading.
var reload_ratio: float = -1.0
var color: Color = Color.WHITE


func _ready() -> void:
	z_index = CombatConstants.Z_ARC
	visible = false


## Updates the display; hidden when there is no magazine (capacity 0).
func show_state(new_ammo: int, new_capacity: int, new_reload_ratio: float, new_color: Color) -> void:
	ammo = new_ammo
	capacity = new_capacity
	reload_ratio = new_reload_ratio
	color = new_color
	visible = capacity > 0
	queue_redraw()


func _draw() -> void:
	if capacity <= 0:
		return
	if reload_ratio >= 0.0:
		var origin: Vector2 = Vector2(-BAR_WIDTH * 0.5, 0.0)
		draw_rect(Rect2(origin, Vector2(BAR_WIDTH, 3.0)), Color(0.0, 0.0, 0.0, 0.6))
		draw_rect(Rect2(origin, Vector2(BAR_WIDTH * reload_ratio, 3.0)), Color(1.0, 0.85, 0.3))
		return
	var total: float = capacity * PIP_SIZE.x + (capacity - 1) * PIP_GAP
	for i: int in capacity:
		var pip: Rect2 = Rect2(Vector2(-total * 0.5 + i * (PIP_SIZE.x + PIP_GAP), 0.0), PIP_SIZE)
		draw_rect(pip, Color(color.lightened(0.4), 1.0) if i < ammo else Color(0.0, 0.0, 0.0, 0.5))
