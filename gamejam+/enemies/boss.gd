class_name Boss
extends EnemyBase
## Boss que se adapta às poções: ao cruzar cada limiar de vida (75%, 50%, 25%) fecha as asas e fica imune
## aos itens da poção que deu o último golpe (as imunidades se acumulam). Os efeitos desses itens deixam de
## valer contra ele: os golpes passam por ProjectileModifiers.for_target(), que pede adapt_modifiers().
## Cada dano recebido tem uma chance pequena de dropar um item.

enum AnimState { IDLE, CLOSING, HOLD, OPENING }

## Nome mostrado na barra de vida
@export var display_name: String = "Anjo Caído"
## Frações da vida máxima que disparam a adaptação (em ordem decrescente)
@export var adapt_thresholds: Array[float] = [0.75, 0.5, 0.25]
## Chance (0-1) de dropar um item a cada dano recebido
@export_range(0.0, 1.0) var drop_chance_per_damage: float = 0.01

@export_group("Animação")
@export var idle_texture: Texture2D
@export var idle_frames: int = 8
@export var idle_fps: float = 8.0
## Folha das asas fechando (tocada de trás para frente para abrir)
@export var wings_texture: Texture2D
@export var wings_frames: int = 4
@export var wings_fps: float = 10.0
## Tempo (s) com as asas fechadas durante a adaptação
@export var adapt_hold_time: float = 0.9
## Cor do flash ao se adaptar
@export var adapt_flash_color: Color = Color(0.75, 0.4, 1.0)

# Itens a que o boss está imune: id -> ItemData (ids iguais = mesmo item)
var _immune: Dictionary = {}
# Itens da poção do último golpe direto ou splash
var _last_hit_items: Array[ItemData] = []
# Próximo limiar de adapt_thresholds ainda não cruzado
var _next_threshold: int = 0
# Modificadores filtrados por poção: id da instância original -> ProjectileModifiers (limpo a cada adaptação)
var _filtered_cache: Dictionary = {}
var _anim_state: AnimState = AnimState.IDLE
var _anim_time: float = 0.0


func _ready() -> void:
	super()
	_set_sheet(idle_texture, idle_frames)
	_health.health_changed.connect(_on_health_changed)
	_health.damaged.connect(_on_damaged)
	EventBus.boss_spawned.emit(self)
	print("[Boss] - %s surgiu (%d de vida)" % [display_name, _health.max_health])


func _process(delta: float) -> void:
	_tick_animation(delta)


## Parado enquanto se adapta (asas fechadas).
func _chase_velocity(target: Node2D) -> Vector2:
	if _anim_state != AnimState.IDLE:
		return Vector2.ZERO
	return super(target)


## Registra a poção do golpe e devolve os modificadores sem os itens a que o boss está imune.
func adapt_modifiers(mods: ProjectileModifiers) -> ProjectileModifiers:
	_last_hit_items = mods.source_items
	if not _has_immune_item(mods.source_items):
		return mods
	var key: int = mods.get_instance_id()
	var filtered: ProjectileModifiers = _filtered_cache.get(key) as ProjectileModifiers
	if filtered == null:
		filtered = mods.without_items(_immune)
		_filtered_cache[key] = filtered
	# A raiva (sinergia Evil) muda durante a luta e vem do jogador, não dos itens
	filtered.rage_multiplier = mods.rage_multiplier
	return filtered


## Itens a que o boss está imune, na ordem em que se adaptou.
func immune_items() -> Array[ItemData]:
	var items: Array[ItemData] = []
	for item: ItemData in _immune.values():
		items.append(item)
	return items


func _has_immune_item(items: Array[ItemData]) -> bool:
	if _immune.is_empty():
		return false
	for item: ItemData in items:
		if _immune.has(item.id):
			return true
	return false


# Cruza os limiares de vida; um golpe que cruza vários adapta uma vez só.
func _on_health_changed(current: int, max_value: int) -> void:
	if _health.is_dead():
		return
	var crossed: bool = false
	while _next_threshold < adapt_thresholds.size() and current <= max_value * adapt_thresholds[_next_threshold]:
		_next_threshold += 1
		crossed = true
	if crossed:
		_adapt()


# Fica imune aos itens da última poção que o acertou e anuncia a adaptação.
func _adapt() -> void:
	var new_items: Array[ItemData] = []
	for item: ItemData in _last_hit_items:
		if item != null and not _immune.has(item.id):
			_immune[item.id] = item
			new_items.append(item)
	if new_items.is_empty():
		print("[Boss] - limiar cruzado, mas a última poção não trouxe itens novos para se adaptar")
		return
	_filtered_cache.clear()
	var names: PackedStringArray = []
	for item: ItemData in new_items:
		names.append(String(item.id))
	print("[Boss] - adaptou-se: imune a %s" % ", ".join(names))
	_play_adapt_feedback()
	EventBus.boss_adapted.emit(new_items, immune_items())


func _play_adapt_feedback() -> void:
	_anim_state = AnimState.CLOSING
	_anim_time = 0.0
	_set_sheet(wings_texture, wings_frames)
	var feedback: HitFeedback = get_node_or_null("HitFeedback") as HitFeedback
	if feedback != null:
		feedback.flash(adapt_flash_color, 0.4)
	EventBus.screen_shake_requested.emit(FeelConstants.TRAUMA_ELITE_DEATH)
	EventBus.play_sfx_requested.emit("room_lock")


# 1% (padrão) de chance de dropar item a cada dano recebido.
func _on_damaged(_amount: int) -> void:
	if randf() < drop_chance_per_damage:
		print("[Boss] - dano soltou um item")
		EventBus.item_drop_requested.emit(LootManager.Source.BOSS_HIT, global_position)


# Idle em loop; adaptação: fecha as asas, segura e abre de volta.
func _tick_animation(delta: float) -> void:
	_anim_time += delta
	match _anim_state:
		AnimState.IDLE:
			_sprite.frame = int(_anim_time * idle_fps) % maxi(idle_frames, 1)
		AnimState.CLOSING:
			var frame: int = int(_anim_time * wings_fps)
			if frame >= wings_frames:
				_anim_state = AnimState.HOLD
				_anim_time = 0.0
				frame = wings_frames - 1
			_sprite.frame = frame
		AnimState.HOLD:
			if _anim_time >= adapt_hold_time:
				_anim_state = AnimState.OPENING
				_anim_time = 0.0
		AnimState.OPENING:
			var frame: int = wings_frames - 1 - int(_anim_time * wings_fps)
			if frame < 0:
				_anim_state = AnimState.IDLE
				_anim_time = 0.0
				_set_sheet(idle_texture, idle_frames)
			else:
				_sprite.frame = frame


func _set_sheet(texture: Texture2D, frames: int) -> void:
	if texture == null:
		return
	_sprite.texture = texture
	_sprite.hframes = maxi(frames, 1)
	_sprite.frame = 0
