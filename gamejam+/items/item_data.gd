class_name ItemData
extends Resource

@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var rarity: ItemEnums.Rarity = ItemEnums.Rarity.BASIC
@export var aspects: Array[ItemEnums.Aspect] = []
@export var effects: Array[ItemEffect] = []
# Cor do item, usada para o líquido da poção
@export var color: Color = Color.WHITE

# Multiplicador de tamanho pela raridade (ver ItemEnums.RARITY_SCALES)
func rarity_scale() -> float:
	return ItemEnums.RARITY_SCALES.get(rarity, 1.0)

# Valida id e quantidade de aspectos (1-3; até 4 somente para LEGENDARY)
func is_valid() -> bool:
	var valid: bool = true
	if id == &"":
		push_warning("[Items] - Item sem id: %s" % display_name)
		valid = false
	var max_aspects: int = ItemEnums.MAX_ASPECTS_LEGENDARY if rarity == ItemEnums.Rarity.LEGENDARY else ItemEnums.MAX_ASPECTS
	if aspects.size() < 1 or aspects.size() > max_aspects:
		push_warning("[Items] - Item '%s' deve ter 1-%d aspectos (tem %d)" % [id, max_aspects, aspects.size()])
		valid = false
	return valid
