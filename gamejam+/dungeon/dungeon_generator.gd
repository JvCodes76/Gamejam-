class_name DungeonGenerator
extends RefCounted
## Gera o grafo de salas de um cemitério numa grade: árvore conexa com exatamente
## 1 sala de spawn, 1 de caldeirão, 1 de item e 1 de saída (boss no último cemitério).

const DIRECTIONS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
# Spawn, caldeirão, item e saída
const MIN_ROOMS: int = 4
const GROW_ATTEMPTS: int = 2000


## Gera as salas (já posicionadas). filler_weights: peso por Type das salas extras (ELITE, HORDE, EMPTY).
static func generate(room_count: int, is_final: bool, filler_weights: Dictionary, pitch_tiles: Vector2i, tile_px: int, rng: RandomNumberGenerator) -> Array[RoomData]:
	var rooms: Array[RoomData] = _grow(maxi(room_count, MIN_ROOMS), rng)
	_assign_types(rooms, is_final, filler_weights, rng)
	for room: RoomData in rooms:
		room.make_doors()
		room.place(pitch_tiles, tile_px)
	return rooms


# Cresce uma árvore: cada nova sala nasce numa célula livre vizinha de uma sala existente.
static func _grow(count: int, rng: RandomNumberGenerator) -> Array[RoomData]:
	var rooms: Array[RoomData] = [RoomData.new(Vector2i.ZERO)]
	var occupied: Dictionary = {Vector2i.ZERO: 0}
	var attempts: int = 0
	while rooms.size() < count and attempts < GROW_ATTEMPTS:
		attempts += 1
		var parent_index: int = rng.randi() % rooms.size()
		var dir: Vector2i = DIRECTIONS[rng.randi() % DIRECTIONS.size()]
		var cell: Vector2i = rooms[parent_index].cell + dir
		if occupied.has(cell):
			continue
		var child: RoomData = RoomData.new(cell)
		var child_index: int = rooms.size()
		rooms.append(child)
		occupied[cell] = child_index
		rooms[parent_index].neighbors[dir] = child_index
		child.neighbors[-dir] = parent_index
	return rooms


# Distância em salas a partir de "start" (BFS).
static func _distances(rooms: Array[RoomData], start: int) -> Array[int]:
	var dist: Array[int] = []
	dist.resize(rooms.size())
	dist.fill(-1)
	dist[start] = 0
	var queue: Array[int] = [start]
	while not queue.is_empty():
		var current: int = queue.pop_front()
		for neighbor: int in rooms[current].neighbors.values():
			if dist[neighbor] == -1:
				dist[neighbor] = dist[current] + 1
				queue.append(neighbor)
	return dist


# Sorteia o papel de cada sala: spawn e saída em becos distantes, item num beco, caldeirão no resto.
static func _assign_types(rooms: Array[RoomData], is_final: bool, filler_weights: Dictionary, rng: RandomNumberGenerator) -> void:
	var unassigned: Array[int] = []
	for i: int in rooms.size():
		unassigned.append(i)

	var spawn: int = _pick(unassigned, rooms, true, rng)
	rooms[spawn].set_type(RoomData.Type.SPAWN)
	unassigned.erase(spawn)

	# Saída: o beco mais distante do spawn (empates sorteados)
	var dist: Array[int] = _distances(rooms, spawn)
	var exit_index: int = -1
	var shuffled: Array[int] = unassigned.duplicate()
	_shuffle(shuffled, rng)
	for i: int in shuffled:
		if rooms[i].is_leaf() and (exit_index == -1 or dist[i] > dist[exit_index]):
			exit_index = i
	if exit_index == -1:
		for i: int in shuffled:
			if exit_index == -1 or dist[i] > dist[exit_index]:
				exit_index = i
	rooms[exit_index].set_type(RoomData.Type.BOSS if is_final else RoomData.Type.EXIT)
	unassigned.erase(exit_index)

	var item: int = _pick(unassigned, rooms, true, rng)
	rooms[item].set_type(RoomData.Type.ITEM)
	unassigned.erase(item)

	var cauldron: int = _pick(unassigned, rooms, false, rng)
	rooms[cauldron].set_type(RoomData.Type.CAULDRON)
	unassigned.erase(cauldron)

	for i: int in unassigned:
		rooms[i].set_type(_pick_weighted(filler_weights, rng))


# Sorteia uma sala da lista, preferindo becos (prefer_leaf) ou salas de passagem (not prefer_leaf).
static func _pick(candidates: Array[int], rooms: Array[RoomData], prefer_leaf: bool, rng: RandomNumberGenerator) -> int:
	var preferred: Array[int] = []
	for i: int in candidates:
		if rooms[i].is_leaf() == prefer_leaf:
			preferred.append(i)
	var pool: Array[int] = preferred if not preferred.is_empty() else candidates
	return pool[rng.randi() % pool.size()]


# Sorteia um tipo pelo peso; sem pesos válidos, a sala fica vazia.
static func _pick_weighted(weights: Dictionary, rng: RandomNumberGenerator) -> RoomData.Type:
	var total: float = 0.0
	for weight: float in weights.values():
		total += maxf(weight, 0.0)
	if total <= 0.0:
		return RoomData.Type.EMPTY
	var roll: float = rng.randf() * total
	for type: RoomData.Type in weights.keys():
		roll -= maxf(float(weights[type]), 0.0)
		if roll <= 0.0:
			return type
	return RoomData.Type.EMPTY


static func _shuffle(list: Array[int], rng: RandomNumberGenerator) -> void:
	for i: int in range(list.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var tmp: int = list[i]
		list[i] = list[j]
		list[j] = tmp
