class_name PumpkinMimicSpawner
extends Node
## Swaps some decorative pumpkins in the "props_root" node for mimics (chance per pumpkin, with a guaranteed minimum).

const PUMPKIN_KINDS: Array[Prop.Kind] = [Prop.Kind.PUMPKIN_PLAIN, Prop.Kind.PUMPKIN_SMILE, Prop.Kind.PUMPKIN_GRIN]

@export var props_root: Node2D
@export var mimic_scene: PackedScene
@export_range(0.0, 1.0) var mimic_chance: float = 0.05
## Minimum number of mimics per run (if there are enough pumpkins).
@export var min_mimics: int = 1


func _ready() -> void:
	if props_root == null:
		return
	var pumpkins: Array[Prop] = []
	for child: Node in props_root.get_children():
		var prop: Prop = child as Prop
		if prop != null and prop.kind in PUMPKIN_KINDS:
			pumpkins.append(prop)
	swap_pumpkins(pumpkins)


## Swaps some of the given pumpkins (already children of "props_root") for mimics.
func swap_pumpkins(pumpkins: Array[Prop]) -> void:
	if props_root == null or mimic_scene == null:
		return
	var chosen: Array[Prop] = pumpkins.filter(func(_p: Prop) -> bool: return randf() < mimic_chance)
	pumpkins.shuffle()
	for prop: Prop in pumpkins:
		if chosen.size() >= min_mimics:
			break
		if prop not in chosen:
			chosen.append(prop)
	for prop: Prop in chosen:
		var mimic: PumpkinMimic = mimic_scene.instantiate() as PumpkinMimic
		mimic.setup(prop.kind)
		mimic.position = prop.position
		props_root.add_child(mimic)
		prop.queue_free()
	print("[Enemy] - %d of %d pumpkins became mimics" % [chosen.size(), pumpkins.size()])
