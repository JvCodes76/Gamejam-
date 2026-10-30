class_name ItemData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var rarity: ItemEnums.Rarity = ItemEnums.Rarity.BASIC
@export var aspects: Array[ItemEnums.Aspect] = []
@export var effects: Array[ItemEffect] = []

# Valida id e quantidade de aspectos (1-3)
func is_valid() -> bool:
	var valid: bool = true
	if id == &"":
		push_warning("[Items] - Item sem id: %s" % display_name)
		valid = false
	if aspects.size() < 1 or aspects.size() > 3:
		push_warning("[Items] - Item '%s' deve ter 1-3 aspectos (tem %d)" % [id, aspects.size()])
		valid = false
	return valid
