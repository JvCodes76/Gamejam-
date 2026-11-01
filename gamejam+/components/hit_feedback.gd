class_name HitFeedback
extends Node
## Reusable hit feedback: listens to the owner's HealthComponent and Hurtbox and applies flash (shader),
## sprite squash, knockback (if the owner has apply_knockback) and requests the damage numbers on the EventBus.

const FLASH_SHADER: Shader = preload("res://assets/shaders/flash.gdshader")

@export var sprite_path: NodePath = ^"../Sprite2D"
@export var health_path: NodePath = ^"../HealthComponent"
@export var hurtbox_path: NodePath = ^"../Hurtbox"
@export var flash_color: Color = Color.WHITE
@export var flash_time: float = FeelConstants.FLASH_TIME
@export var squash_scale: Vector2 = FeelConstants.SQUASH_SCALE
@export var squash_time: float = FeelConstants.SQUASH_TIME
@export var knockback_impulse: float = FeelConstants.KNOCKBACK_IMPULSE
@export var show_damage_numbers: bool = true

var _sprite: Sprite2D
var _health: HealthComponent
var _hurtbox: Hurtbox
var _material: ShaderMaterial
var _base_scale: Vector2 = Vector2.ONE
var _flash_tween: Tween
var _squash_tween: Tween


func _ready() -> void:
	_sprite = get_node_or_null(sprite_path) as Sprite2D
	_health = get_node_or_null(health_path) as HealthComponent
	_hurtbox = get_node_or_null(hurtbox_path) as Hurtbox
	if _sprite != null:
		_material = make_flash_material(flash_color)
		_sprite.material = _material
		_base_scale = _sprite.scale
	if _health != null:
		_health.damaged.connect(_on_damaged)
		_health.damage_negated.connect(_on_damage_negated)
	if _hurtbox != null:
		_hurtbox.hit_received.connect(_on_hit_received)


## Creates its own flash material (each sprite needs its own, the uniform is per material).
static func make_flash_material(color: Color) -> ShaderMaterial:
	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = FLASH_SHADER
	mat.set_shader_parameter("flash_color", color)
	mat.set_shader_parameter("flash", 0.0)
	return mat


## Base scale of the sprite (without squash); useful for whoever animates the sprite from outside (spawn).
func base_scale() -> Vector2:
	return _base_scale


## Flashes the sprite in the flash color (or in "color", if given).
func flash(color: Color = flash_color, duration: float = flash_time) -> void:
	if _material == null:
		return
	_material.set_shader_parameter("flash_color", color)
	if _flash_tween != null:
		_flash_tween.kill()
	_material.set_shader_parameter("flash", 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash, 1.0, 0.0, duration).set_delay(duration * 0.5)


## Squashes the sprite and returns with an elastic tween.
func squash() -> void:
	if _sprite == null:
		return
	if _squash_tween != null:
		_squash_tween.kill()
	_sprite.scale = _base_scale * squash_scale
	_squash_tween = create_tween()
	_squash_tween.tween_property(_sprite, "scale", _base_scale, squash_time).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Point above the sprite's head (in global coordinates).
func head_position() -> Vector2:
	if _sprite == null:
		return (get_parent() as Node2D).global_position
	var rect: Rect2 = _sprite.get_rect()
	return _sprite.global_position + Vector2(0.0, rect.position.y * _base_scale.y)


func _set_flash(value: float) -> void:
	_material.set_shader_parameter("flash", value)


# Direct hit: knockback in the direction of the hit
func _on_hit_received(direction: Vector2, _is_crit: bool) -> void:
	var owner_node: Node = get_parent()
	if direction != Vector2.ZERO and owner_node.has_method("apply_knockback"):
		owner_node.call("apply_knockback", direction * knockback_impulse)


# Real damage: flash, squash and damage number (DoT ticks only flash lightly, the number comes from enemy_dot_ticked)
func _on_damaged(amount: int) -> void:
	if _health.applying_dot:
		flash(flash_color, flash_time * 0.5)
		return
	flash()
	squash()
	if show_damage_numbers:
		var crit: bool = _hurtbox != null and _hurtbox.last_hit_crit
		EventBus.damage_dealt.emit(head_position(), amount, crit, FeelConstants.DAMAGE_NUMBER_CRIT_COLOR if crit else FeelConstants.DAMAGE_NUMBER_COLOR)


func _on_damage_negated(_amount: int) -> void:
	if show_damage_numbers:
		EventBus.damage_blocked.emit(head_position())
