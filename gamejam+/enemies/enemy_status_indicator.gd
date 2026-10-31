class_name EnemyStatusIndicator
extends Node2D
## Indicadores de status desenhados por código sobre o inimigo (Fase 2: viram ícones 8x8).
## Stun: estrelas em órbita. Slow: gotas azuis caindo. Marked: losango vermelho pulsando.
## Veneno/DoT: bolhas subindo. Raiz: linhas marrons no pé. Charm: coraçõezinhos.

const STUN_COLOR: Color = Color(1.0, 0.95, 0.4)
const SLOW_COLOR: Color = Color(0.5, 0.75, 1.0, 0.9)
const MARKED_COLOR: Color = Color(1.0, 0.2, 0.25)
const ROOTS_COLOR: Color = Color(0.5, 0.33, 0.15)
const CHARM_COLOR: Color = Color(1.0, 0.45, 0.75)

var _effects: StatusEffects
var _health: HealthComponent
var _sprite: Sprite2D
var _time: float = 0.0
var _was_drawing: bool = false


func setup(effects: StatusEffects, health: HealthComponent, sprite: Sprite2D) -> void:
	_effects = effects
	_health = health
	_sprite = sprite


func _process(delta: float) -> void:
	var active: bool = _has_anything()
	if active:
		_time += delta
	if active or _was_drawing:
		queue_redraw()
	_was_drawing = active


func _has_anything() -> bool:
	if _effects == null:
		return false
	return _effects.has_any() or (_health != null and not _health.active_dot_sources().is_empty())


# Topo da cabeça em coordenadas locais (o nó fica na origem do inimigo, nos pés)
func _head_y() -> float:
	if _sprite == null:
		return -32.0
	return _sprite.position.y + _sprite.get_rect().position.y * absf(_sprite.scale.y)


func _body_y() -> float:
	return _sprite.position.y if _sprite != null else -16.0


func _draw() -> void:
	if not _has_anything():
		return
	var head: float = _head_y()
	var stack: float = head - 4.0
	if _effects.has(StatusEffects.STUN):
		_draw_stun(head - 1.0)
	if _effects.has(StatusEffects.MARKED):
		_draw_marked(stack)
		stack -= 9.0
	if _effects.has(StatusEffects.CHARMED):
		_draw_hearts(stack)
	if _effects.has(StatusEffects.SLOW):
		_draw_slow(head)
	if _effects.has(StatusEffects.ROOTS):
		_draw_roots()
	if _health != null:
		var sources: Array = _health.active_dot_sources()
		for i: int in sources.size():
			var color: Color = FeelConstants.DOT_COLORS.get(sources[i], Color(0.45, 1.0, 0.35))
			_draw_bubbles(color, float(i) * 1.7)


# 3 estrelinhas girando numa órbita achatada sobre a cabeça
func _draw_stun(y: float) -> void:
	for i: int in 3:
		var a: float = _time * 6.0 + TAU * float(i) / 3.0
		var p: Vector2 = Vector2(cos(a) * 7.0, y + sin(a) * 2.5)
		draw_line(p + Vector2(-1.5, 0), p + Vector2(1.5, 0), STUN_COLOR, 1.0)
		draw_line(p + Vector2(0, -1.5), p + Vector2(0, 1.5), STUN_COLOR, 1.0)


# Losango vermelho pulsando acima da cabeça
func _draw_marked(y: float) -> void:
	var s: float = 3.0 * (1.0 + 0.2 * sin(_time * 8.0))
	var c: Vector2 = Vector2(0.0, y)
	var points: PackedVector2Array = PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.75, 0), c + Vector2(0, s), c + Vector2(-s * 0.75, 0)])
	draw_colored_polygon(points, MARKED_COLOR)
	points.append(points[0])
	draw_polyline(points, Color(1, 1, 1, 0.8), 1.0)


# Gotas azuis caindo da cabeça até o meio do corpo
func _draw_slow(head: float) -> void:
	var span: float = maxf(_body_y() - head, 8.0)
	for i: int in 3:
		var x: float = (float(i) - 1.0) * 6.0
		var y: float = head + fmod(_time * 18.0 + float(i) * span / 3.0, span)
		draw_rect(Rect2(x, y, 1.0, 2.0), SLOW_COLOR)


# Bolhas subindo pelo corpo (veneno, fogo, raiz, lama: cor da fonte)
func _draw_bubbles(color: Color, phase: float) -> void:
	var bottom: float = -2.0
	var top: float = _head_y()
	var span: float = maxf(bottom - top, 8.0)
	for i: int in 3:
		var t: float = fmod(_time * 0.9 + phase + float(i) / 3.0, 1.0)
		var x: float = sin((t + float(i)) * 5.0 + phase) * 5.0
		var y: float = bottom - t * span
		draw_circle(Vector2(x, y), 1.0 + (1.0 - t) * 0.5, Color(color, 1.0 - t * 0.7))


# Linhas marrons saindo do chão em volta dos pés
func _draw_roots() -> void:
	for i: int in 5:
		var x: float = (float(i) - 2.0) * 3.0
		var h: float = 3.0 + 1.5 * sin(_time * 3.0 + float(i))
		draw_line(Vector2(x, 1.0), Vector2(x + (1.0 if i % 2 == 0 else -1.0) * 2.0, 1.0 - h), ROOTS_COLOR, 1.0)


# Coraçõezinhos (2 círculos + triângulo) flutuando
func _draw_hearts(y: float) -> void:
	for i: int in 2:
		var x: float = (float(i) - 0.5) * 8.0
		var bob: float = sin(_time * 4.0 + float(i) * 1.5) * 1.5
		var c: Vector2 = Vector2(x, y + bob)
		draw_circle(c + Vector2(-1.0, 0.0), 1.2, CHARM_COLOR)
		draw_circle(c + Vector2(1.0, 0.0), 1.2, CHARM_COLOR)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-2.2, 0.3), c + Vector2(2.2, 0.3), c + Vector2(0.0, 2.8)]), CHARM_COLOR)
