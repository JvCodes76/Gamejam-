class_name MagicArc
extends Line2D
## Raio de magia (sinergia Magic): visual curto do arco entre dois inimigos e o salto de dano.


## Acerta o inimigo vizinho mais próximo (sem repetir) com a fração do dano da arma; no tier 6 o raio quica de volta.
static func chain_from(first: Hurtbox, mods: ProjectileModifiers, base_damage: int) -> void:
	var origin: EnemyBase = first.get_parent() as EnemyBase
	if origin == null:
		return
	var origin_pos: Vector2 = origin.global_position
	var neighbor: EnemyBase = _nearest_neighbor(origin)
	if neighbor == null:
		return
	var neighbor_pos: Vector2 = neighbor.global_position
	var scene: Node = origin.get_tree().current_scene
	var color: Color = mods.color.lerp(SynergyConstants.MAGIC_ARC_COLOR, 0.5)
	var dmg: int = mods.for_target(neighbor.get_hurtbox()).roll_secondary_damage(base_damage, SynergyConstants.MAGIC_ARC_FRACTION)
	neighbor.get_hurtbox().receive_hit(dmg)
	_draw_arc(scene, origin_pos, neighbor_pos, color, 4.0)
	print("[Synergy] - raio saltou para %s (dano %d)" % [neighbor_pos, dmg])
	if mods.synergy.arc_bounce and origin.is_alive():
		var back: int = mods.roll_secondary_damage(base_damage, SynergyConstants.MAGIC_ARC_FRACTION)
		origin.get_hurtbox().receive_hit(back)
		_draw_arc(scene, neighbor_pos, origin_pos, color, -4.0)
		print("[Synergy] - raio quicou de volta (dano %d)" % back)


## Inimigo vivo mais próximo de "from" dentro do alcance do raio (nunca o próprio).
static func _nearest_neighbor(from: EnemyBase) -> EnemyBase:
	var best: EnemyBase = null
	var best_dist: float = SynergyConstants.MAGIC_ARC_RANGE * SynergyConstants.MAGIC_ARC_RANGE
	for node: Node in from.get_tree().get_nodes_in_group("enemy"):
		var other: EnemyBase = node as EnemyBase
		if other == null or other == from or not other.is_alive():
			continue
		var dist: float = from.global_position.distance_squared_to(other.global_position)
		if dist <= best_dist:
			best_dist = dist
			best = other
	return best


## Desenha um arco em zigue-zague de "a" até "b" que some em MAGIC_ARC_TIME.
static func _draw_arc(scene: Node, a: Vector2, b: Vector2, color: Color, jag: float) -> void:
	var line: MagicArc = MagicArc.new()
	var side: Vector2 = (b - a).orthogonal().normalized() * jag
	line.points = PackedVector2Array([a, a.lerp(b, 0.5) + side, b])
	line.position = CombatConstants.ENEMY_BODY_OFFSET
	line.width = SynergyConstants.MAGIC_ARC_WIDTH
	line.default_color = color
	line.z_index = CombatConstants.Z_ARC
	scene.add_child(line)
	var tween: Tween = line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, SynergyConstants.MAGIC_ARC_TIME)
	tween.tween_callback(line.queue_free)
