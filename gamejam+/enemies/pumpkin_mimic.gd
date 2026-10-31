class_name PumpkinMimic
extends EnemyBase
## Abóbora mímico: parece uma abóbora decorativa até ser ativada, quando persegue o player.
## Ativa se levar qualquer dano ou se o player chegar a "wake_radius" px. Dormindo, não conta como inimigo
## (fora do grupo "enemy"), não fere o player e não se move; a hurtbox continua atingível.

@export var wake_radius: float = 70.0
@export var anim_fps: float = 8.0

var disguise_kind: Prop.Kind = Prop.Kind.PUMPKIN_PLAIN
var _awake: bool = false
var _anim_time: float = 0.0


## Define de qual abóbora (tipo do Prop) o mímico se disfarça; chamar antes de add_child.
func setup(kind: Prop.Kind) -> void:
	disguise_kind = kind


func _ready() -> void:
	super._ready()
	remove_from_group("enemy")
	_hitbox.suppressed = true
	_health.damaged.connect(_on_damaged)
	var region: Rect2 = Prop.get_def(disguise_kind)["region"]
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = Prop.TILESET_TEXTURE
	atlas.region = region
	_sprite.texture = atlas
	_sprite.hframes = 1
	_sprite.position = Vector2(0.0, -region.size.y / 2.0)
	print("[Enemy] - mímico de abóbora disfarçado em %s" % global_position)


func _physics_process(delta: float) -> void:
	if not _awake:
		var player: Node2D = get_tree().get_first_node_in_group("player") as Node2D
		if player != null and global_position.distance_to(player.global_position) <= wake_radius:
			_wake_up()
		return
	super._physics_process(delta)


func _process(delta: float) -> void:
	if not _awake:
		return
	_anim_time += delta
	_sprite.frame = int(_anim_time * anim_fps) % _sprite.hframes


func _on_damaged(_amount: int) -> void:
	_wake_up()


## Revela o mímico: troca para a folha ativa, volta ao grupo "enemy" e passa a perseguir o player.
func _wake_up() -> void:
	if _awake:
		return
	_awake = true
	add_to_group("enemy")
	_hitbox.suppressed = _status.has(StatusEffects.STUN)
	_sprite.texture = load("res://assets/sprites/Enemies/Enemy_PumpkinMimic-Sheet.png") as Texture2D
	_sprite.hframes = 4
	_sprite.frame = 0
	_sprite.position = Vector2(0.0, -16.0)
	_play_wake_feedback()
	print("[Enemy] - mímico de abóbora ativado")


# Pulo, squash, tremida, "!" sobre a cabeça e som
func _play_wake_feedback() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(_sprite, "position:y", -28.0, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(_sprite, "position:y", -16.0, 0.14).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	var feedback: HitFeedback = get_node_or_null("HitFeedback") as HitFeedback
	if feedback != null:
		feedback.squash()
	var scene: Node = get_tree().current_scene
	if scene != null:
		FloatingText.spawn(scene, global_position + Vector2(0.0, -40.0), "!", Color(1.0, 0.6, 0.1), 14, 0.7, 20.0)
	EventBus.screen_shake_requested.emit(FeelConstants.TRAUMA_MIMIC_WAKE)
	EventBus.play_sfx_requested.emit("mimic_wake")
