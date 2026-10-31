class_name Player
extends CharacterBody2D

const BULLET_SCENE: PackedScene = preload("res://projectiles/bullet.tscn")

@export var move_speed: float = 110.0
@export var acceleration: float = 900.0
@export var friction: float = 1200.0
@export var fire_rate_seconds: float = 0.45
@export var aim_deadzone: float = 0.3
@export var gamepad_crosshair_distance: float = 60.0
@export var walk_frame_time: float = 0.18
@export var cape_frame_time: float = 0.12
# Pixels que a cabeça sobe nos quadros "andando"
@export var head_bob: float = 1.0
## Invencibilidade após levar dano (s)
@export var invulnerability_time: float = 0.8
@export var knockback_impulse: float = FeelConstants.PLAYER_KNOCKBACK_IMPULSE

var _fire_timer: float = 0.0
var _aim_direction: Vector2 = Vector2.RIGHT
var _use_gamepad: bool = false
var _mods: ProjectileModifiers = ProjectileModifiers.new()
var _director: SynergyDirector = null
var _walk_timer: float = 0.0
var _walk_frame: int = 0
var _cape_timer: float = 0.0
var _cape_frame: int = 0
var _head_base_y: float = 0.0
# Posição no ciclo de cores do arco-íris (receita RAINBOWS!!!)
var _rainbow_index: int = 0
# Game feel: recuo do sprite no tiro, knockback, piscar dos i-frames e morte
var _recoil_offset: Vector2 = Vector2.ZERO
var _cape_base_position: Vector2 = Vector2.ZERO
var _knockback: Vector2 = Vector2.ZERO
var _blink_time: float = 0.0
var _dead: bool = false
var _flash_materials: Array[ShaderMaterial] = []
var _flash_tween: Tween

# Folha com 4 direções x 2 quadros (parado/andando): baixo, direita, esquerda, cima
const FRAMES_PER_DIRECTION: int = 2
enum Facing { DOWN, RIGHT, LEFT, UP }

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _cape: Sprite2D = $Cape
@onready var _body_center: Marker2D = $BodyCenter
@onready var _pivot: Node2D = $Pivot
@onready var _muzzle: Marker2D = $Pivot/Muzzle
@onready var _health: HealthComponent = $HealthComponent
@onready var _crosshair: Crosshair = $Crosshair
@onready var _camera: GameCamera = $Camera2D
@onready var _hurtbox: Hurtbox = $Hurtbox
@onready var _muzzle_flash: MuzzleFlash = $Pivot/Muzzle/MuzzleFlash


## Centro do corpo no mundo. A origem do nó fica nos pés (y-sort e colisão);
## a mira, o muzzle e as sinergias "do corpo" partem daqui.
var aim_origin: Vector2:
	get:
		return _body_center.global_position


func _ready() -> void:
	_head_base_y = _sprite.position.y
	_cape_base_position = _cape.position
	_hurtbox.invulnerability_time = invulnerability_time
	for sprite: Sprite2D in [_sprite, _cape]:
		var mat: ShaderMaterial = HitFeedback.make_flash_material(FeelConstants.FLASH_HURT_COLOR)
		sprite.material = mat
		_flash_materials.append(mat)
	_health.health_changed.connect(_on_health_changed)
	_health.damaged.connect(_on_damaged)
	_health.died.connect(_on_died)
	_director = SynergyDirector.new()
	_director.name = "SynergyDirector"
	add_child(_director)
	_director.setup(self, _health)
	# Adiado para o HUD (que vem depois na árvore) já estar conectado
	EventBus.player_health_changed.emit.call_deferred(_health.current_health, _health.max_health)
	EventBus.game_paused.connect(_on_game_paused)
	EventBus.potion_selected.connect(_on_potion_selected)
	EventBus.potion_slots_changed.connect(_recalculate_modifiers)
	EventBus.active_effects_changed.connect(_recalculate_modifiers)
	_recalculate_modifiers()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	print("[Player] - pronto")


## Restaura o cursor do sistema ao sair da cena.
func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


## Volta a mirar com o mouse quando ele se move.
func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_use_gamepad = false


## Alterna a poção ativa com o scroll do mouse.
func _unhandled_input(event: InputEvent) -> void:
	if _dead or ItemManager.inventory_open or not event is InputEventMouseButton:
		return
	var mouse: InputEventMouseButton = event as InputEventMouseButton
	if not mouse.pressed:
		return
	if mouse.button_index == MOUSE_BUTTON_WHEEL_UP:
		ItemManager.cycle_potion(1)
	elif mouse.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		ItemManager.cycle_potion(-1)


func _physics_process(delta: float) -> void:
	_update_aim()
	_handle_movement(delta)
	_update_sprite(delta)
	_update_blink(delta)
	_fire_timer -= delta
	if Input.is_action_pressed("shoot") and _fire_timer <= 0.0 and not ItemManager.inventory_open:
		_shoot()


## Move o jogador em 8 direções com aceleração e atrito.
func _handle_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		velocity = velocity.move_toward(input_dir * move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	if _knockback == Vector2.ZERO:
		move_and_slide()
		return
	# Knockback soma só neste passo; a velocidade de caminhada continua a mesma
	var walk_velocity: Vector2 = velocity
	velocity += _knockback
	move_and_slide()
	velocity = walk_velocity
	_knockback = _knockback.move_toward(Vector2.ZERO, FeelConstants.KNOCKBACK_FRICTION * delta)


## Atualiza a mira (analógico ou mouse), gira o Pivot e posiciona o crosshair.
func _update_aim() -> void:
	# Com o inventário aberto a mira fica congelada e o crosshair some
	if ItemManager.inventory_open:
		_crosshair.visible = false
		return
	_crosshair.visible = not get_tree().paused
	var stick: Vector2 = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() > aim_deadzone:
		_use_gamepad = true
		_aim_direction = stick.normalized()
		_crosshair.global_position = aim_origin + _aim_direction * gamepad_crosshair_distance
	elif not _use_gamepad:
		var mouse_pos: Vector2 = get_global_mouse_position()
		var to_mouse: Vector2 = mouse_pos - aim_origin
		if to_mouse.length() > 1.0:
			_aim_direction = to_mouse.normalized()
		_crosshair.global_position = mouse_pos
	else:
		_crosshair.global_position = aim_origin + _aim_direction * gamepad_crosshair_distance
	_pivot.rotation = _aim_direction.angle()
	_camera.look_target = _crosshair.global_position


## Escolhe a direção do sprite pela mira e alterna os 2 quadros enquanto anda.
func _update_sprite(delta: float) -> void:
	var facing: Facing = _facing_from(_aim_direction)
	if velocity.length() > 5.0:
		_walk_timer += delta
		if _walk_timer >= walk_frame_time:
			_walk_timer = 0.0
			_walk_frame = 1 - _walk_frame
	else:
		_walk_timer = 0.0
		_walk_frame = 0
	_update_cape(delta, velocity.length() > 5.0)
	_recoil_offset = _recoil_offset.move_toward(Vector2.ZERO, FeelConstants.SPRITE_RECOIL / FeelConstants.SPRITE_RECOIL_TIME * delta)
	_sprite.position = Vector2(_recoil_offset.x, _head_base_y - (head_bob if _walk_frame == 1 else 0.0) + _recoil_offset.y)
	_cape.position = _cape_base_position + _recoil_offset
	_sprite.frame = facing * FRAMES_PER_DIRECTION + _walk_frame


## Anima a capa: parada no quadro 0, cicla os 4 quadros ao andar.
func _update_cape(delta: float, walking: bool) -> void:
	if walking:
		_cape_timer += delta
		if _cape_timer >= cape_frame_time:
			_cape_timer = 0.0
			_cape_frame = (_cape_frame + 1) % _cape.hframes
	else:
		_cape_timer = 0.0
		_cape_frame = 0
	_cape.frame = _cape_frame


## Converte a direção da mira em uma das 4 direções da folha.
func _facing_from(direction: Vector2) -> Facing:
	if absf(direction.x) > absf(direction.y):
		return Facing.RIGHT if direction.x > 0.0 else Facing.LEFT
	return Facing.DOWN if direction.y > 0.0 else Facing.UP


## Dispara uma bala na direção da mira.
func _shoot() -> void:
	_fire_timer = fire_rate_seconds / _mods.fire_rate_multiplier
	var bullet: Bullet = BULLET_SCENE.instantiate() as Bullet
	bullet.global_position = _muzzle.global_position
	var shot_dir: Vector2 = _aim_direction
	if not _use_gamepad:
		var to_mouse: Vector2 = get_global_mouse_position() - _muzzle.global_position
		if to_mouse.length() > 1.0:
			shot_dir = to_mouse.normalized()
	bullet.damage = CombatConstants.WEAPON_BASE_DAMAGE
	bullet.setup(shot_dir)
	bullet.apply_modifiers(_mods, _health)
	if _mods.synergy.rainbow_colors:
		if not bullet.is_holy():
			bullet.set_tint(SynergyConstants.RAINBOW_COLORS[_rainbow_index % SynergyConstants.RAINBOW_COLORS.size()])
		_rainbow_index += 1
	get_tree().current_scene.add_child(bullet)
	_muzzle_flash.flash(bullet.get_tint())
	_recoil_offset = -shot_dir * FeelConstants.SPRITE_RECOIL
	_camera.kick(shot_dir)
	EventBus.play_sfx_requested.emit("shoot")


## Recalcula os modificadores a partir da poção ativa e tinge o crosshair.
func _recalculate_modifiers() -> void:
	var potion: PotionData = ItemManager.get_active_potion()
	var specials: Array[StringName] = potion.special_synergies if potion != null else ([] as Array[StringName])
	_mods = ProjectileModifiers.from_totals(ItemManager.get_active_effect_totals(), potion.aspect_counts if potion != null else {}, specials)
	if potion != null:
		_mods.color = potion.color
	_director.configure(_mods, potion.aspect_counts if potion != null else {})
	_crosshair.color = Color(_mods.color, 0.9)
	_crosshair.queue_redraw()
	_crosshair.pulse()
	print("[Potion] - modificadores: dano x%.2f, alcance x%.2f, cadência x%.2f" % [_mods.damage_multiplier, _mods.range_multiplier, _mods.fire_rate_multiplier])


## Avisa uma vez dos efeitos não implementados ao trocar de poção.
func _on_potion_selected(index: int) -> void:
	_recalculate_modifiers()
	_mods.print_unimplemented()


## Alterna cursor do sistema e crosshair conforme a pausa.
func _on_game_paused(paused: bool) -> void:
	if ItemManager.inventory_open:
		return
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_HIDDEN
	_crosshair.visible = not paused


## Repassa a mudança de vida ao EventBus.
func _on_health_changed(current: int, max_value: int) -> void:
	EventBus.player_health_changed.emit(current, max_value)


## Dano: flash vermelho, tremida, hitstop, knockback e aviso no EventBus (os i-frames ficam na Hurtbox).
func _on_damaged(_amount: int) -> void:
	if _health.is_dead():
		return
	_flash(FeelConstants.FLASH_HURT_COLOR, 0.15)
	var direction: Vector2 = _hurtbox.last_hit_direction
	if direction != Vector2.ZERO:
		_knockback = direction.normalized() * knockback_impulse
	_blink_time = 0.0
	EventBus.screen_shake_requested.emit(FeelConstants.TRAUMA_PLAYER_HURT)
	EventBus.hitstop_requested.emit(FeelConstants.HITSTOP_PLAYER_HURT_MS / 1000.0)
	EventBus.player_hurt.emit(global_position)
	EventBus.play_sfx_requested.emit("player_hurt")


## Pisca alternando a transparência durante os i-frames.
func _update_blink(delta: float) -> void:
	if _hurtbox.is_invulnerable():
		_blink_time += delta
		var on: bool = int(_blink_time / FeelConstants.PLAYER_BLINK_INTERVAL) % 2 == 0
		var alpha: float = 1.0 if on else 0.25
		_sprite.modulate.a = alpha
		_cape.modulate.a = alpha
	elif _sprite.modulate.a < 1.0:
		_sprite.modulate.a = 1.0
		_cape.modulate.a = 1.0


## Pisca o sprite e a capa numa cor (shader de flash).
func _flash(color: Color, duration: float) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	for mat: ShaderMaterial in _flash_materials:
		mat.set_shader_parameter("flash_color", color)
		mat.set_shader_parameter("flash", 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_method(_set_flash, 1.0, 0.0, duration).set_delay(duration * 0.4)


func _set_flash(value: float) -> void:
	for mat: ShaderMaterial in _flash_materials:
		mat.set_shader_parameter("flash", value)


## Trata a morte do jogador: player_died sai na hora; o corpo fica como "cadáver" visual até a troca de cena.
func _on_died() -> void:
	print("[Player] - morreu")
	_dead = true
	EventBus.player_died.emit()
	remove_from_group("player")
	set_physics_process(false)
	set_process_unhandled_input(false)
	_hurtbox.set_deferred("monitorable", false)
	_crosshair.visible = false
	_muzzle_flash.visible = false
	_camera.frozen = true
	_sprite.modulate.a = 1.0
	_cape.modulate.a = 1.0
	_flash(Color.WHITE, 0.4)
	EventBus.slowmo_requested.emit(FeelConstants.PLAYER_DEATH_SLOWMO, FeelConstants.PLAYER_DEATH_SLOWMO_TIME)
	EventBus.screen_shake_requested.emit(FeelConstants.TRAUMA_PLAYER_DEATH)
	EventBus.play_sfx_requested.emit("player_die")
	ImpactEffect.spawn_burst(self, _body_center.position, 40.0, Color(1.0, 0.3, 0.3), 40, 0.9, 2.0, 2.0)
	var tween: Tween = create_tween()
	tween.tween_interval(FeelConstants.PLAYER_CORPSE_TIME)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
