class_name AmbienceLayer
extends Node2D
## Night atmosphere of a level, all behind the "Atmosphere effects" toggle (AmbienceSettings):
## night lighting with lamp posts, jack-o'-lanterns, candles, portal, cauldron and a soft light around the player,
## vignette, ground fog, fireflies and falling leaves, and drop shadows under props and actors.
## Off = nothing is created (zero cost): the layers and decorations are freed and rebuilt when it comes back on.
## Usage: add ambience_layer.tscn as a child of the level root (any moment; existing and future nodes are decorated).

const DECORATION_GROUP: StringName = &"ambience_decoration"
const DECORATED_META: StringName = &"ambience_decorated"
const PLAYER_GROUP: StringName = &"player"
const PORTAL_GROUP: StringName = &"portal"
## Render layer (bit index) of every ambience visual: viewports that render the world for other purposes (the
## minimap capture) leave this bit out of their canvas_cull_mask
const VISIBILITY_LAYER_BIT: int = 19
# Margin (px) around the view when culling lights
const VIEW_MARGIN: float = 48.0

# Light presets: color, radius (px on the ground), energy, flicker (0-1), speed, offset (center of the light pool
# relative to the owner's feet), halo (radius px, 0 = none), halo_energy, halo_at (glowing spot relative to the feet),
# glow (additive brightness over the pool of light)
const LIGHT_LAMP: Dictionary = {"color": Color(1.0, 0.86, 0.55), "radius": 96.0, "energy": 0.7, "flicker": 0.05, "speed": 3.0,
	"offset": Vector2(0, -8), "halo": 14, "halo_energy": 0.5, "halo_at": Vector2(0, -31), "glow": 0.16}
const LIGHT_JACK_LIT: Dictionary = {"color": Color(1.0, 0.62, 0.25), "radius": 56.0, "energy": 0.65, "flicker": 0.18, "speed": 7.0,
	"offset": Vector2(0, -4), "halo": 12, "halo_energy": 0.45, "halo_at": Vector2(0, -7), "glow": 0.16}
const LIGHT_JACK_DIM: Dictionary = {"color": Color(1.0, 0.58, 0.22), "radius": 40.0, "energy": 0.45, "flicker": 0.25, "speed": 6.0,
	"offset": Vector2(0, -4), "halo": 9, "halo_energy": 0.3, "halo_at": Vector2(0, -8), "glow": 0.1}
const LIGHT_CANDLES: Dictionary = {"color": Color(1.0, 0.85, 0.55), "radius": 40.0, "energy": 0.55, "flicker": 0.22, "speed": 9.0,
	"offset": Vector2(0, -4), "halo": 9, "halo_energy": 0.5, "halo_at": Vector2(0, -10), "glow": 0.14}
const LIGHT_LOG_LANTERN: Dictionary = {"color": Color(1.0, 0.82, 0.5), "radius": 56.0, "energy": 0.6, "flicker": 0.1, "speed": 4.0,
	"offset": Vector2(-6, -4), "halo": 9, "halo_energy": 0.45, "halo_at": Vector2(-7, -10), "glow": 0.14}
const LIGHT_PORTAL: Dictionary = {"color": Color(0.7, 0.45, 1.0), "radius": 120.0, "energy": 0.8, "flicker": 0.06, "speed": 2.0,
	"halo": 30, "halo_energy": 0.25, "glow": 0.14}
const LIGHT_CAULDRON: Dictionary = {"radius": 64.0, "energy": 0.55, "flicker": 0.12, "speed": 5.0,
	"offset": Vector2(0, -6), "halo": 12, "halo_energy": 0.3, "halo_at": Vector2(0, -22), "glow": 0.12}
const LIGHT_FIRE_SKULL: Dictionary = {"color": Color(1.0, 0.6, 0.25), "radius": 60.0, "energy": 0.55, "flicker": 0.15, "speed": 8.0,
	"offset": Vector2(0, -6), "glow": 0.1}
const LIGHT_FIRE_SKULL_ELITE: Dictionary = {"color": Color(1.0, 0.55, 0.2), "radius": 90.0, "energy": 0.65, "flicker": 0.15, "speed": 8.0,
	"offset": Vector2(0, -10), "glow": 0.12}
const LIGHT_GHOST_ELITE: Dictionary = {"color": Color(0.55, 0.85, 1.0), "radius": 72.0, "energy": 0.5, "flicker": 0.08, "speed": 2.5,
	"offset": Vector2(0, -10), "glow": 0.08}
const LIGHT_BOSS: Dictionary = {"color": Color(0.95, 0.8, 1.0), "radius": 140.0, "energy": 0.55, "flicker": 0.05, "speed": 1.5,
	"offset": Vector2(0, -20), "glow": 0.08}

const PROP_LIGHTS: Dictionary = {
	Prop.Kind.LAMP_POST: LIGHT_LAMP,
	Prop.Kind.PUMPKIN_GRIN: LIGHT_JACK_LIT,
	Prop.Kind.PUMPKIN_SMILE: LIGHT_JACK_DIM,
	Prop.Kind.CANDLES: LIGHT_CANDLES,
	Prop.Kind.LOG_LANTERN: LIGHT_LOG_LANTERN,
}
# Enemies that glow, by scene
const ENEMY_LIGHTS: Dictionary = {
	"res://enemies/fire_skull.tscn": LIGHT_FIRE_SKULL,
	"res://enemies/fire_skull_elite.tscn": LIGHT_FIRE_SKULL_ELITE,
	"res://enemies/ghost_elite.tscn": LIGHT_GHOST_ELITE,
	"res://enemies/boss_fallen_angel.tscn": LIGHT_BOSS,
}
# Props standing on the ground get a shadow (flat ones, arches and fences do not)
const SHADOW_PROPS: Array[Prop.Kind] = [
	Prop.Kind.GRAVE_CROSS, Prop.Kind.GRAVE_ROUND, Prop.Kind.GRAVE_BROKEN, Prop.Kind.CANDLES,
	Prop.Kind.PUMPKIN_PLAIN, Prop.Kind.PUMPKIN_SMILE, Prop.Kind.PUMPKIN_GRIN, Prop.Kind.LAMP_POST,
	Prop.Kind.HOLLOW_TREE_A, Prop.Kind.HOLLOW_TREE_B, Prop.Kind.BUSH_A, Prop.Kind.BUSH_B,
	Prop.Kind.BENCH, Prop.Kind.LOG_LANTERN,
]
# Prop shadow: at least this share of the sprite width, or the footprint widened by this factor
const PROP_SHADOW_SPRITE_SHARE: float = 0.7
const PROP_SHADOW_FOOTPRINT_SCALE: float = 1.15
const PLAYER_SHADOW_SIZE: Vector2i = Vector2i(14, 5)
const CAULDRON_SHADOW_SIZE: Vector2i = Vector2i(38, 10)

@export_group("Lighting")
## Everything far from a light is multiplied by this color (white = no darkening). Keep it bright: the game must stay readable.
@export var ambient_color: Color = Color(0.72, 0.68, 0.87)
## Nothing gets darker than this (per channel), even at the corners
@export_range(0.0, 1.0) var min_brightness: float = 0.42
@export_range(0.0, 1.0) var vignette_strength: float = 0.22
## Steps in the light falloff (0 = smooth; 4 to 6 gives a pixel-art look)
@export_range(0, 12) var light_bands: int = 0
## Multiplies the energy of every light (lamps, pumpkins, portal...)
@export var light_energy_scale: float = 1.0
## Soft light that follows the player, so the area around them is always visible
@export var player_light_color: Color = Color(1.0, 0.9, 0.65)
@export var player_light_radius: float = 120.0
@export var player_light_energy: float = 0.35

@export_group("Fog")
@export var fog_enabled: bool = true
@export var fog_color: Color = Color(0.8, 0.78, 0.95)
## Maximum opacity of the thickest patches
@export_range(0.0, 1.0) var fog_density: float = 0.3
## Smaller = bigger patches
@export var fog_scale: float = 0.008
## Drift of the fog and push on the leaves (px/s)
@export var wind: Vector2 = Vector2(7.0, 2.5)

@export_group("Particles")
@export var firefly_count: int = 14
@export var leaf_count: int = 12

@export_group("Shadows")
@export var shadows_enabled: bool = true
@export var shadow_color: Color = Color(0.08, 0.04, 0.16)
@export_range(0.0, 1.0) var shadow_alpha: float = 0.35

var _lighting: NightLighting = null
var _fog: GroundFog = null
var _particles: AmbientParticles = null
# Nodes that entered the tree while their parent was busy: decorated on the next frame
var _pending: Array[Node] = []
var _active: bool = false


func _ready() -> void:
	set_process(false)
	EventBus.ambience_toggled.connect(_set_active)
	_set_active(AmbienceSettings.is_enabled())


func _exit_tree() -> void:
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)


func _process(_delta: float) -> void:
	if not _pending.is_empty():
		var nodes: Array[Node] = _pending
		_pending = []
		for node: Node in nodes:
			if is_instance_valid(node) and node.is_inside_tree():
				_decorate(node)
	_update_view()


# Builds or tears down everything (setting toggled, also live from the pause menu).
func _set_active(enabled: bool) -> void:
	if enabled == _active:
		return
	_active = enabled
	set_process(enabled)
	if enabled:
		_build_layers()
		get_tree().node_added.connect(_on_node_added)
		_decorate_tree(get_parent())
		_update_view()
	else:
		get_tree().node_added.disconnect(_on_node_added)
		_pending.clear()
		_free_layers()
		_clear_decorations()
	print("[Ambience] - %s" % ("built" if enabled else "removed"))


func _build_layers() -> void:
	_lighting = NightLighting.new()
	_lighting.configure(ambient_color, min_brightness, vignette_strength, light_bands)
	_add_visual(self, _lighting)
	if fog_enabled:
		_fog = GroundFog.new()
		_fog.configure(fog_color, fog_density, fog_scale, wind)
		_add_visual(self, _fog)
	_particles = AmbientParticles.new()
	_particles.configure(firefly_count, leaf_count, wind)
	_add_visual(self, _particles)


# Every ambience visual goes on its own render layer (children inherit the exclusion)
func _add_visual(parent: Node, visual: Node2D) -> void:
	visual.visibility_layer = 1 << VISIBILITY_LAYER_BIT
	parent.add_child(visual)


func _free_layers() -> void:
	for layer: Node in [_lighting, _fog, _particles]:
		if layer != null:
			layer.queue_free()
	_lighting = null
	_fog = null
	_particles = null


# Removes lights and shadows right away (out of the tree now, freed at the end of the frame)
func _clear_decorations() -> void:
	for decoration: Node in get_tree().get_nodes_in_group(DECORATION_GROUP):
		var owner_node: Node = decoration.get_parent()
		if owner_node != null:
			owner_node.remove_meta(DECORATED_META)
			owner_node.remove_child(decoration)
		decoration.queue_free()


# Camera view in world coordinates (the level is on the default canvas)
func _update_view() -> void:
	var viewport: Viewport = get_viewport()
	var canvas: Transform2D = viewport.get_canvas_transform()
	var size: Vector2 = viewport.get_visible_rect().size
	var center: Vector2 = canvas.affine_inverse() * (size * 0.5)
	var half_view: Vector2 = size * 0.5 / canvas.get_scale()
	var cover: float = half_view.length() + VIEW_MARGIN
	if _lighting != null:
		var view: Rect2 = Rect2(center - half_view, half_view * 2.0).grow(VIEW_MARGIN)
		_lighting.update_view(center, cover, view, Time.get_ticks_msec() / 1000.0)
	if _fog != null:
		_fog.update_view(center, cover)
	if _particles != null:
		_particles.update_view(center, half_view)


# --- Decorations (lights and shadows attached to level nodes) ---

func _on_node_added(node: Node) -> void:
	if _wants(node):
		_pending.append(node)


func _wants(node: Node) -> bool:
	return node is Prop or node is EnemyBase or node is Cauldron or node.is_in_group(PLAYER_GROUP) or node.is_in_group(PORTAL_GROUP)


# Walks the level once (on load or when the setting is turned on)
func _decorate_tree(root: Node) -> void:
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node == self:
			continue
		if _wants(node):
			_decorate(node)
		stack.append_array(node.get_children())


func _decorate(node: Node) -> void:
	if node.has_meta(DECORATED_META):
		return
	node.set_meta(DECORATED_META, true)
	var target: Node2D = node as Node2D
	if node is PumpkinMimic:
		# Asleep it must look exactly like the pumpkin it replaced (same light and shadow)
		_decorate_prop(target, (node as PumpkinMimic).disguise_kind)
	elif node is Prop:
		_decorate_prop(target, (node as Prop).kind)
	elif node is EnemyBase:
		_decorate_enemy(node as EnemyBase)
	elif node is Cauldron:
		var cauldron: Cauldron = node as Cauldron
		var light: LightSource = _add_light(target, LIGHT_CAULDRON)
		light.color_provider = func() -> Color: return cauldron.state.potion.color if cauldron.state.potion != null else cauldron.idle_bubble_color
		_add_shadow(target, CAULDRON_SHADOW_SIZE, Vector2(0, -2))
	elif node.is_in_group(PLAYER_GROUP):
		var light: LightSource = _add_light(target, {"radius": player_light_radius, "energy": player_light_energy, "offset": Vector2(0, -12)})
		light.light_color = player_light_color
		_add_shadow(target, PLAYER_SHADOW_SIZE, Vector2(0, -1))
	elif node.is_in_group(PORTAL_GROUP):
		_add_light(target, LIGHT_PORTAL)


func _decorate_prop(node: Node2D, kind: Prop.Kind) -> void:
	if PROP_LIGHTS.has(kind):
		_add_light(node, PROP_LIGHTS[kind])
	if kind in SHADOW_PROPS:
		var shadow: Rect2 = _prop_shadow_rect(kind)
		_add_shadow(node, DropShadow.size_for_width(shadow.size.x), shadow.get_center())


func _decorate_enemy(enemy: EnemyBase) -> void:
	if ENEMY_LIGHTS.has(enemy.scene_file_path):
		_add_light(enemy, ENEMY_LIGHTS[enemy.scene_file_path])
	var sprite: Sprite2D = enemy.get_node_or_null(^"Sprite2D") as Sprite2D
	if sprite == null:
		return
	# The spawn "pop" starts the sprite at scale 0: the HitFeedback keeps the real one (with the elite enlargement)
	var feedback: HitFeedback = enemy.get_node_or_null(^"HitFeedback") as HitFeedback
	var sprite_scale: Vector2 = feedback.base_scale() if feedback != null else sprite.scale
	_add_shadow(enemy, DropShadow.size_for_sprite(sprite, sprite_scale), Vector2(0, -1))


# Shadow rectangle of a prop (local to its feet): the footprint widened, at least a share of the sprite width
func _prop_shadow_rect(kind: Prop.Kind) -> Rect2:
	var def: Dictionary = Prop.get_def(kind)
	var region: Rect2 = def["region"]
	var origin: Vector2 = Prop.origin_of(kind)
	var foot: Rect2 = Rect2(region.size.x * 0.3, region.size.y - 4.0, region.size.x * 0.4, 3.0)
	var rects: Array = def["rects"]
	if not rects.is_empty():
		var points: PackedVector2Array = PackedVector2Array()
		for entry: Variant in rects:
			points.append_array(Prop.footprint_points(entry))
		foot = Rect2(points[0], Vector2.ZERO)
		for point: Vector2 in points:
			foot = foot.expand(point)
	var width: float = maxf(foot.size.x * PROP_SHADOW_FOOTPRINT_SCALE, region.size.x * PROP_SHADOW_SPRITE_SHARE)
	return Rect2(Vector2(foot.get_center().x - width * 0.5, foot.position.y) - origin, Vector2(width, foot.size.y))


func _add_light(target: Node2D, preset: Dictionary) -> LightSource:
	var light: LightSource = LightSource.from_preset(preset, light_energy_scale)
	_attach(target, light)
	return light


func _add_shadow(target: Node2D, size: Vector2i, at: Vector2) -> void:
	if not shadows_enabled:
		return
	var shadow: DropShadow = DropShadow.create(size, shadow_color, shadow_alpha)
	shadow.position = at
	_attach(target, shadow)


func _attach(target: Node2D, decoration: Node2D) -> void:
	decoration.add_to_group(DECORATION_GROUP)
	_add_visual(target, decoration)
