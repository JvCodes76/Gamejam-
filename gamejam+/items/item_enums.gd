class_name ItemEnums
extends RefCounted

# Aspectos (classes) dos itens
enum Aspect { PLANT, POISON, EARTH, ROCK, ANIMAL, DARKNESS, LIGHT, MAGIC, EVIL }
# Raridade dos itens
enum Rarity { BASIC, INTERMEDIATE, ADVANCED, LEGENDARY }

# Cores de raridade (cinza, verde, azul, dourado)
const RARITY_COLORS: Dictionary = {
	Rarity.BASIC: Color(0.7, 0.7, 0.7),
	Rarity.INTERMEDIATE: Color(0.4, 0.85, 0.4),
	Rarity.ADVANCED: Color(0.4, 0.6, 1.0),
	Rarity.LEGENDARY: Color(1.0, 0.8, 0.2),
}

# Cores de aspecto: matizes distintos entre si e das cores de raridade
const ASPECT_COLORS: Dictionary = {
	Aspect.PLANT: Color(0.1, 0.75, 0.65),
	Aspect.POISON: Color(0.72, 0.35, 0.95),
	Aspect.EARTH: Color(0.5, 0.3, 0.15),
	Aspect.ROCK: Color(0.92, 0.45, 0.72),
	Aspect.ANIMAL: Color(0.92, 0.28, 0.28),
	Aspect.DARKNESS: Color(0.2, 0.15, 0.55),
	Aspect.LIGHT: Color(1.0, 1.0, 0.75),
	Aspect.MAGIC: Color(0.55, 0.1, 0.75),
	Aspect.EVIL: Color(0.45, 0.0, 0.1),
}

# Multiplicador de tamanho do sprite por raridade (balanceamento: edite aqui).
# O lendário é 1.0 porque o sprite já é 32x32 (o dobro dos demais).
const RARITY_SCALES: Dictionary = {
	Rarity.BASIC: 1.0,
	Rarity.INTERMEDIATE: 1.2,
	Rarity.ADVANCED: 1.5,
	Rarity.LEGENDARY: 1.0,
}
# Máximo de aspectos por item; só LEGENDARY pode ter MAX_ASPECTS_LEGENDARY
const MAX_ASPECTS: int = 3
const MAX_ASPECTS_LEGENDARY: int = 4
