class_name EnemyDeathFx
extends Node2D
## "Cadáver" visual de um inimigo: cópia do sprite que pisca branco, cresce e some, mais um burst de partículas
## na cor do inimigo e alguns pedaços do próprio sprite. A lógica de morte (enemy_died) já rodou; isto é só visual.

const PARTICLE_LIFETIME: float = 0.5

# Cor média (pixels opacos) de cada textura, calculada uma vez
static var _color_cache: Dictionary = {}


## Cria o efeito a partir do sprite do inimigo (adição deferida: seguro dentro de callbacks de física).
static func spawn(scene: Node, sprite: Sprite2D, world_position: Vector2) -> EnemyDeathFx:
	var fx: EnemyDeathFx = EnemyDeathFx.new()
	fx.name = "EnemyDeathFx"
	fx.global_position = world_position
	fx._build(sprite)
	scene.add_child.call_deferred(fx)
	return fx


func _build(source: Sprite2D) -> void:
	var copy: Sprite2D = Sprite2D.new()
	copy.texture = source.texture
	copy.hframes = source.hframes
	copy.vframes = source.vframes
	copy.frame = source.frame
	copy.flip_h = source.flip_h
	copy.centered = source.centered
	copy.offset = source.offset
	copy.position = source.position
	copy.scale = source.scale
	copy.modulate = source.modulate
	copy.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat: ShaderMaterial = HitFeedback.make_flash_material(Color.WHITE)
	mat.set_shader_parameter("flash", 1.0)
	copy.material = mat
	add_child(copy)
	var color: Color = average_color(source.texture) * source.modulate
	_add_burst(copy.position, color)
	_add_chunks(source, copy.position)
	var tween: Tween = create_tween().set_parallel()
	tween.tween_property(copy, "scale", copy.scale * FeelConstants.DEATH_POP_SCALE, FeelConstants.DEATH_POP_TIME).set_ease(Tween.EASE_OUT)
	tween.tween_property(copy, "modulate:a", 0.0, FeelConstants.DEATH_POP_TIME)
	tween.chain().tween_interval(PARTICLE_LIFETIME)
	tween.chain().tween_callback(queue_free)


## Cor média dos pixels opacos da textura (cache por textura).
static func average_color(texture: Texture2D) -> Color:
	if texture == null:
		return Color.WHITE
	var key: int = texture.get_rid().get_id()
	if _color_cache.has(key):
		return _color_cache[key]
	var image: Image = texture.get_image()
	var result: Color = Color.WHITE
	if image != null:
		if image.is_compressed():
			image.decompress()
		var sum: Color = Color(0, 0, 0, 0)
		var count: int = 0
		var step: int = maxi(1, int(maxf(image.get_width(), image.get_height()) / 48.0))
		for y: int in range(0, image.get_height(), step):
			for x: int in range(0, image.get_width(), step):
				var c: Color = image.get_pixel(x, y)
				if c.a > 0.5:
					sum += c
					count += 1
		if count > 0:
			result = Color(sum.r / count, sum.g / count, sum.b / count, 1.0)
	_color_cache[key] = result
	return result


# Burst de partículas quadradas (pixel art) na cor do inimigo
func _add_burst(center: Vector2, color: Color) -> void:
	var img: Image = Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var p: CPUParticles2D = _make_emitter(ImageTexture.create_from_image(img), FeelConstants.DEATH_PARTICLES, center)
	p.initial_velocity_min = 30.0
	p.initial_velocity_max = 90.0
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	var fade: Gradient = Gradient.new()
	fade.set_color(0, Color(color.lightened(0.3), 1.0))
	fade.set_color(1, Color(color, 0.0))
	p.color_ramp = fade


# Pedaços do próprio sprite voando (2 emissores, cada um com um recorte diferente do quadro atual)
func _add_chunks(source: Sprite2D, center: Vector2) -> void:
	var texture: Texture2D = source.texture
	if texture == null:
		return
	var base: Texture2D = texture
	var origin: Vector2 = Vector2.ZERO
	var atlas_src: AtlasTexture = texture as AtlasTexture
	if atlas_src != null:
		base = atlas_src.atlas
		origin = atlas_src.region.position
	var frame_size: Vector2 = texture.get_size() / Vector2(source.hframes, source.vframes)
	var frame_pos: Vector2 = Vector2(source.frame % source.hframes, floorf(float(source.frame) / source.hframes)) * frame_size
	var chunk: float = FeelConstants.DEATH_CHUNK_SIZE / maxf(absf(source.scale.x), 0.01)
	chunk = minf(chunk, minf(frame_size.x, frame_size.y) * 0.5)
	for i: int in 2:
		var local: Vector2 = frame_size * 0.5 + Vector2(randf_range(-0.25, 0.25), randf_range(-0.25, 0.25)) * frame_size - Vector2(chunk, chunk) * 0.5
		var piece: AtlasTexture = AtlasTexture.new()
		piece.atlas = base
		piece.region = Rect2(origin + frame_pos + local, Vector2(chunk, chunk))
		var p: CPUParticles2D = _make_emitter(piece, ceili(FeelConstants.DEATH_CHUNKS * 0.5), center)
		p.initial_velocity_min = 40.0
		p.initial_velocity_max = 80.0
		p.gravity = Vector2(0.0, 220.0)
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
		p.scale_amount_min = absf(source.scale.x)
		p.scale_amount_max = absf(source.scale.x)
		p.modulate = source.modulate
		var fade: Gradient = Gradient.new()
		fade.set_color(0, Color.WHITE)
		fade.set_color(1, Color(1, 1, 1, 0))
		p.color_ramp = fade


func _make_emitter(texture: Texture2D, amount: int, center: Vector2) -> CPUParticles2D:
	var p: CPUParticles2D = CPUParticles2D.new()
	p.texture = texture
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.position = center
	p.amount = maxi(amount, 1)
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = PARTICLE_LIFETIME
	p.direction = Vector2.UP
	p.spread = 180.0
	p.gravity = Vector2(0.0, 60.0)
	add_child(p)
	p.emitting = true
	return p
