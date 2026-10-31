class_name RoomData
extends RefCounted
## Dados de uma sala do cemitério: tipo, posição na grade, tamanho, retângulo no mundo e portas.

# Tipos (cores do desenho): SPAWN ciano, CAULDRON laranja, ITEM amarelo, EXIT roxo, BOSS (exit do último cemitério),
# ELITE azul, HORDE vermelho, EMPTY branco (passagem sem inimigos)
enum Type { SPAWN, CAULDRON, ITEM, EXIT, BOSS, ELITE, HORDE, EMPTY }

# Tamanho de cada tipo em tiles (valores pares, para os centros das salas alinharem na grade)
const SIZES: Dictionary = {
	Type.SPAWN: Vector2i(24, 16),
	Type.CAULDRON: Vector2i(36, 22),
	Type.ITEM: Vector2i(24, 16),
	Type.EXIT: Vector2i(24, 16),
	Type.BOSS: Vector2i(48, 30),
	Type.ELITE: Vector2i(40, 24),
	Type.HORDE: Vector2i(44, 26),
	Type.EMPTY: Vector2i(28, 18),
}

# Cor de depuração de cada tipo (mesma paleta do desenho do level)
const DEBUG_COLORS: Dictionary = {
	Type.SPAWN: Color(0.0, 1.0, 1.0),
	Type.CAULDRON: Color(1.0, 0.5, 0.0),
	Type.ITEM: Color(1.0, 1.0, 0.0),
	Type.EXIT: Color(1.0, 0.0, 1.0),
	Type.BOSS: Color(0.5, 0.0, 0.0),
	Type.ELITE: Color(0.0, 0.0, 1.0),
	Type.HORDE: Color(1.0, 0.0, 0.0),
	Type.EMPTY: Color(1.0, 1.0, 1.0),
}

## Porta numa parede de cima ou de baixo. "offset" é o x relativo ao centro da sala (px):
## vizinhos acima/abaixo usam o centro; vizinhos laterais usam um vão deslocado na parede de baixo
## (o corredor sai por baixo, dá a volta e entra pela parede de baixo da outra sala).
class Door extends RefCounted:
	var side: Vector2i = Vector2i.DOWN
	var offset: float = 0.0
	var neighbor: int = -1
	var blocker: StaticBody2D = null
	# Arco da porta (aberto/fechado)
	var arch: Prop = null

# Distância (px) dos vãos laterais ao centro da parede de baixo
const SIDE_DOOR_OFFSET: float = 96.0

var type: Type = Type.EMPTY
var cell: Vector2i = Vector2i.ZERO
var size_tiles: Vector2i = Vector2i.ZERO
# Retângulo do chão da sala em px de mundo
var rect: Rect2 = Rect2()
# Direção na grade (Vector2i) -> índice da sala vizinha
var neighbors: Dictionary = {}
# Portas da sala: todas na parede de cima ou de baixo
var doors: Array[Door] = []
var visited: bool = false
var cleared: bool = false


func _init(new_cell: Vector2i) -> void:
	cell = new_cell


## Define o tipo e o tamanho correspondente.
func set_type(new_type: Type) -> void:
	type = new_type
	size_tiles = SIZES[new_type]


## Fecha ou abre as portas da sala: bloqueio de colisão e portão do arco.
func set_doors_closed(closed: bool) -> void:
	for door: Door in doors:
		if door.blocker != null:
			door.blocker.collision_layer = PhysicsLayers.WORLD if closed else 0
		if door.arch != null:
			door.arch.kind = Prop.Kind.ARCH_GATE if closed else Prop.Kind.ARCH_OPEN


## Retorna true se a sala tem uma única ligação (beco sem saída).
func is_leaf() -> bool:
	return neighbors.size() == 1


## Cria as portas a partir dos vizinhos: acima/abaixo no centro; laterais deslocadas na parede de baixo.
func make_doors() -> void:
	doors.clear()
	for dir: Vector2i in neighbors.keys():
		var door: Door = Door.new()
		door.neighbor = neighbors[dir]
		if dir == Vector2i.UP or dir == Vector2i.DOWN:
			door.side = dir
		else:
			door.side = Vector2i.DOWN
			door.offset = SIDE_DOOR_OFFSET * float(dir.x)
		doors.append(door)


## Porta que leva à sala "neighbor_index" (null se não existe).
func door_to(neighbor_index: int) -> Door:
	for door: Door in doors:
		if door.neighbor == neighbor_index:
			return door
	return null


## Calcula o retângulo no mundo: a sala fica centralizada na sua célula da grade.
@warning_ignore("integer_division")
func place(pitch_tiles: Vector2i, tile_px: int) -> void:
	var origin: Vector2i = cell * pitch_tiles + (pitch_tiles - size_tiles) / 2
	rect = Rect2(Vector2(origin * tile_px), Vector2(size_tiles * tile_px))


## Centro do chão da sala.
func center() -> Vector2:
	return rect.get_center()
