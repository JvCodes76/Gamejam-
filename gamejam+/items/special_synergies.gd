class_name SpecialSynergies
extends RefCounted
## Receitas especiais: ativas quando TODOS os item_ids aparecem pelo menos uma vez na poção.
## Várias receitas podem estar ativas ao mesmo tempo e combinam com as sinergias de aspecto.
## Nota: "match" é palavra reservada do GDScript, por isso a função se chama find_matches().

const SALAD: StringName = &"salad"
const EVIL_SALAD: StringName = &"evil_salad"
const SPICE_BAG: StringName = &"spice_bag"
const BUTCHER: StringName = &"unethical_butcher"
const CRUNCHY: StringName = &"crunchy"
const RESPECTS: StringName = &"press_f"
const RAINBOWS: StringName = &"rainbows"
const TEA: StringName = &"not_tea"
const EYE_DROPS: StringName = &"eye_drops"
const POTENTIALIZER: StringName = &"potentializer"

## Tabela de receitas: id, nome exibido, ids dos itens e descrição curta (inglês).
const RECIPES: Array[Dictionary] = [
	{"id": SALAD, "name": "Salad!", "item_ids": [&"carrot", &"mushroom", &"salt"],
		"description": "+4% lifesteal chance"},
	{"id": EVIL_SALAD, "name": "EVIL Salad!!", "item_ids": [&"mushroom", &"poisonous_mushroom", &"deathcap"],
		"description": "+10% poison chance"},
	{"id": SPICE_BAG, "name": "Spice bag", "item_ids": [&"cinnamon", &"star_anise", &"mandrake_root"],
		"description": "Shots leave a slowing cloud"},
	{"id": BUTCHER, "name": "Unethical Butcher :(", "item_ids": [&"wolf_tooth", &"salamander_tail", &"spider_gland", &"eye_of_giant_newt"],
		"description": "Marked enemies may drop a healing orb"},
	{"id": CRUNCHY, "name": "Crunchy!", "item_ids": [&"salt", &"obsidian", &"rose_quartz"],
		"description": "Stunned enemies take +10% damage"},
	{"id": RESPECTS, "name": "Press F to pay respects", "item_ids": [&"rose_petal", &"graveyard_dirt"],
		"description": "Charmed enemies return as ghosts"},
	{"id": RAINBOWS, "name": "RAINBOWS!!!", "item_ids": [&"rose_petal", &"unicorn_horn_shavings"],
		"description": "+10% charm, +1 bounce, rainbow shots"},
	{"id": TEA, "name": "Do NOT make this tea.", "item_ids": [&"gilded_rosemary", &"wolfsbane"],
		"description": "Piercing may drain 20% of a basic enemy's health"},
	{"id": EYE_DROPS, "name": "Weird Eye Drops.", "item_ids": [&"tree_sap", &"eye_of_giant_newt"],
		"description": "Shots split in two on hit"},
	{"id": POTENTIALIZER, "name": "Magical Potentializer", "item_ids": [&"gunpowder", &"unicorn_horn_shavings"],
		"description": "Explosions +20% bigger and stronger"},
]


## Receitas ativas para uma lista de itens (cada uma como o Dictionary da tabela).
static func find_matches(items: Array[ItemData]) -> Array[Dictionary]:
	var present: Dictionary = {}
	for item: ItemData in items:
		if item != null:
			present[item.id] = true
	var out: Array[Dictionary] = []
	for recipe: Dictionary in RECIPES:
		var complete: bool = true
		for item_id: StringName in recipe["item_ids"]:
			if not present.has(item_id):
				complete = false
				break
		if complete:
			out.append(recipe)
	return out


## Apenas os ids das receitas ativas.
static func find_ids(items: Array[ItemData]) -> Array[StringName]:
	var ids: Array[StringName] = []
	for recipe: Dictionary in find_matches(items):
		ids.append(recipe["id"])
	return ids


## Receitas (Dictionary da tabela) correspondentes a uma lista de ids, na ordem da tabela.
static func recipes_for(ids: Array[StringName]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for recipe: Dictionary in RECIPES:
		if ids.has(recipe["id"]):
			out.append(recipe)
	return out
