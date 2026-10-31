class_name ItemEnums
extends RefCounted

# Aspectos (classes) dos itens
enum Aspect { PLANT, POISON, EARTH, ROCK, ANIMAL }
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
}
