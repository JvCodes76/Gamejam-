class_name DropShadow
extends Sprite2D
## Pixel-art ellipse (opaque core, lighter rim) under a prop or an actor. Drawn on the ground (absolute z_index), so
## it never covers anything standing. Created by the AmbienceLayer.

## Above the floor and fallen leaves, below the fog (GroundFog.Z_LAYER), items and actors
const Z_LAYER: int = -5
# The rim covers the outer part of the ellipse (normalized squared distance) with this alpha; the core is opaque
const RIM_START: float = 0.45
const RIM_ALPHA: float = 0.55
# Share of the opaque sprite width that the shadow covers, and its height relative to the width
const WIDTH_FACTOR: float = 0.75
const HEIGHT_FACTOR: float = 0.32
const MIN_SIZE: Vector2i = Vector2i(8, 4)
const MAX_SIZE: Vector2i = Vector2i(96, 20)

static var _textures: Dictionary = {}
static var _opaque_widths: Dictionary = {}


## Creates a shadow of "size" px (tinted "color" with "alpha"); position it at the feet of the owner.
static func create(size: Vector2i, color: Color, alpha: float) -> DropShadow:
	var shadow: DropShadow = DropShadow.new()
	shadow.name = "DropShadow"
	shadow.texture = _texture_for(size)
	shadow.self_modulate = Color(color, alpha)
	shadow.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	shadow.z_as_relative = false
	shadow.z_index = Z_LAYER
	return shadow


## Shadow size for a sprite drawn at "sprite_scale": a share of the opaque width of its first frame.
static func size_for_sprite(sprite: Sprite2D, sprite_scale: Vector2) -> Vector2i:
	var width: int = clampi(roundi(opaque_width(sprite) * absf(sprite_scale.x) * WIDTH_FACTOR), MIN_SIZE.x, MAX_SIZE.x)
	return Vector2i(width, clampi(roundi(width * HEIGHT_FACTOR), MIN_SIZE.y, MAX_SIZE.y))


## Shadow size for a ground footprint "width" px wide.
static func size_for_width(width: float) -> Vector2i:
	var w: int = clampi(roundi(width), MIN_SIZE.x, MAX_SIZE.x)
	return Vector2i(w, clampi(roundi(w * HEIGHT_FACTOR), MIN_SIZE.y, MAX_SIZE.y))


## Width (px) of the opaque pixels in the first frame of the sprite (read once per texture).
static func opaque_width(sprite: Sprite2D) -> float:
	var texture: Texture2D = sprite.texture
	if texture == null:
		return 16.0
	var frame: Vector2i = Vector2i(texture.get_width() / sprite.hframes, texture.get_height() / sprite.vframes)
	var key: String = "%s#%d:%dx%d" % [texture.resource_path, texture.get_instance_id(), sprite.hframes, sprite.vframes]
	if _opaque_widths.has(key):
		return _opaque_widths[key]
	var width: float = frame.x * 0.6
	var image: Image = texture.get_image()
	if image != null:
		if image.is_compressed():
			image.decompress()
		var left: int = frame.x
		var right: int = -1
		for y: int in frame.y:
			for x: int in frame.x:
				if image.get_pixel(x, y).a > 0.5:
					left = mini(left, x)
					right = maxi(right, x)
		if right >= left:
			width = float(right - left + 1)
	_opaque_widths[key] = width
	return width


# Two-tone ellipse, shared per size
static func _texture_for(size: Vector2i) -> ImageTexture:
	if _textures.has(size):
		return _textures[size]
	var image: Image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
	var half: Vector2 = Vector2(size) * 0.5
	for y: int in size.y:
		for x: int in size.x:
			var n: Vector2 = (Vector2(x, y) + Vector2(0.5, 0.5) - half) / half
			var d: float = n.length_squared()
			if d <= 1.0:
				image.set_pixel(x, y, Color(1.0, 1.0, 1.0, 1.0 if d < RIM_START else RIM_ALPHA))
	var texture: ImageTexture = ImageTexture.create_from_image(image)
	_textures[size] = texture
	return texture
