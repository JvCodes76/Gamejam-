extends Node

enum State { MENU, PLAYING, PAUSED, GAME_OVER, VICTORY }

const LEVEL_PATH: String = "res://levels/dungeon_level.tscn"
const MENU_PATH: String = "res://ui/main_menu.tscn"

## Espera (s) entre a morte do player e o sumário da run
@export var death_summary_delay: float = 1.5
## Espera (s) entre a morte do boss e o sumário da run (deixa a câmera lenta e o "SALA LIMPA" tocarem)
@export var victory_summary_delay: float = 1.8

var state: State = State.MENU
var score: int = 0
# Sala atual (1 = primeira); sem triggers por enquanto
var room_index: int = 1
# Cemitério atual (1 = primeiro) e semente da partida (as salas de cada cemitério derivam dela)
var cemetery_index: int = 1
var run_seed: int = 0
# Modo infinito: quantas vezes o boss final já foi derrotado (0 = primeira volta)
var loop_index: int = 0
# Acessibilidade: desliga a tremida de tela
var reduce_screen_shake: bool = false

# --- Estatísticas da run (sumário) ---
var kills: int = 0
var elite_kills: int = 0
var bosses_defeated: int = 0
var potions_brewed: int = 0
var items_collected: int = 0
var rooms_visited: int = 0
# Tempo jogado em segundos reais (o hitstop zera o Engine.time_scale, então não usa delta)
var run_time: float = 0.0

var _last_tick_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.enemy_died.connect(_on_enemy_died)
	EventBus.player_died.connect(_on_player_died)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	EventBus.potion_brewed.connect(_on_potion_brewed)
	EventBus.item_picked_up.connect(_on_item_picked_up)


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_msec()
	if state == State.PLAYING and not get_tree().paused:
		run_time += float(now - _last_tick_msec) / 1000.0
	_last_tick_msec = now


## Zera o estado e carrega o level principal.
func start_game() -> void:
	score = 0
	room_index = 1
	cemetery_index = 1
	loop_index = 0
	run_seed = randi()
	_reset_stats()
	ItemManager.reset()
	EventBus.score_changed.emit(score)
	state = State.PLAYING
	get_tree().paused = false
	EventBus.scene_change_requested.emit(LEVEL_PATH)
	print("[Game] - partida iniciada")


## Avança para a próxima sala e avisa o EventBus.
func advance_room() -> void:
	room_index += 1
	rooms_visited += 1
	print("[Game] - sala %d" % room_index)
	EventBus.room_changed.emit(room_index)


## Passa para o próximo cemitério: os itens encolhem, o chão é limpo e o level é gerado de novo.
func advance_cemetery() -> void:
	cemetery_index += 1
	room_index = 1
	ItemManager.ground_entries.clear()
	ItemManager.advance_floor()
	print("[Game] - cemitério %d" % cemetery_index)
	EventBus.scene_change_requested.emit(LEVEL_PATH)


## Modo infinito: volta ao primeiro cemitério mantendo itens, poções e pontos, com inimigos mais fortes.
func continue_endless() -> void:
	if state != State.VICTORY:
		return
	loop_index += 1
	cemetery_index = 1
	room_index = 1
	# Nova semente: os mapas da nova volta são diferentes dos já vistos
	run_seed = randi()
	ItemManager.ground_entries.clear()
	ItemManager.advance_floor()
	state = State.PLAYING
	get_tree().paused = false
	print("[Game] - modo infinito: loop %d" % (loop_index + 1))
	EventBus.scene_change_requested.emit(LEVEL_PATH)


## Alterna entre jogando e pausado. Ignora fora de partida.
func toggle_pause() -> void:
	if state != State.PLAYING and state != State.PAUSED:
		return
	var paused: bool = state == State.PLAYING
	state = State.PAUSED if paused else State.PLAYING
	get_tree().paused = paused
	EventBus.game_paused.emit(paused)


## Despausa e volta ao menu principal.
func quit_to_menu() -> void:
	get_tree().paused = false
	state = State.MENU
	EventBus.game_paused.emit(false)
	EventBus.scene_change_requested.emit(MENU_PATH)


## Reinicia a partida atual (usado após game over).
func restart() -> void:
	start_game()


# Zera os contadores mostrados no sumário da run
func _reset_stats() -> void:
	kills = 0
	elite_kills = 0
	bosses_defeated = 0
	potions_brewed = 0
	items_collected = 0
	rooms_visited = 0
	run_time = 0.0
	_last_tick_msec = Time.get_ticks_msec()


func _on_enemy_killed(points: int) -> void:
	score += points
	EventBus.score_changed.emit(score)


# Conta abates para o sumário (elites e boss não são básicos)
func _on_enemy_died(_position: Vector2, _was_marked: bool, is_basic: bool) -> void:
	if state != State.PLAYING:
		return
	kills += 1
	if not is_basic:
		elite_kills += 1


func _on_potion_brewed(_color: Color, _position: Vector2) -> void:
	potions_brewed += 1


func _on_item_picked_up(_item_id: StringName) -> void:
	items_collected += 1


func _on_player_died() -> void:
	if state != State.PLAYING:
		return
	state = State.GAME_OVER
	print("[Game] - game over com %d pontos (loop %d)" % [score, loop_index + 1])
	await get_tree().create_timer(death_summary_delay, true, false, true).timeout
	# Ignora se o jogador já saiu da tela de game over (ex.: voltou ao menu e iniciou outra partida)
	if state != State.GAME_OVER:
		return
	get_tree().paused = true
	EventBus.run_ended.emit(false)


# Boss final derrotado: fecha o loop atual e oferece encerrar a run ou seguir no modo infinito
func _on_boss_defeated() -> void:
	if state != State.PLAYING:
		return
	state = State.VICTORY
	bosses_defeated += 1
	print("[Game] - boss derrotado (loop %d)" % (loop_index + 1))
	await get_tree().create_timer(victory_summary_delay, true, false, true).timeout
	if state != State.VICTORY:
		return
	get_tree().paused = true
	EventBus.run_ended.emit(true)
