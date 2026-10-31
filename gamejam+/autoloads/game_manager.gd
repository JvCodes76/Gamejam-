extends Node

enum State { MENU, PLAYING, PAUSED, GAME_OVER }

const LEVEL_PATH: String = "res://levels/main_level.tscn"
const MENU_PATH: String = "res://ui/main_menu.tscn"

var state: State = State.MENU
var score: int = 0
# Sala atual (1 = primeira); sem triggers por enquanto
var room_index: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.player_died.connect(_on_player_died)


## Zera o estado e carrega o level principal.
func start_game() -> void:
	score = 0
	room_index = 1
	ItemManager.reset()
	EventBus.score_changed.emit(score)
	state = State.PLAYING
	get_tree().paused = false
	EventBus.scene_change_requested.emit(LEVEL_PATH)
	print("[Game] - partida iniciada")


## Avança para a próxima sala e avisa o EventBus.
func advance_room() -> void:
	room_index += 1
	print("[Game] - sala %d" % room_index)
	EventBus.room_changed.emit(room_index)


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


func _on_enemy_killed(points: int) -> void:
	score += points
	EventBus.score_changed.emit(score)


func _on_player_died() -> void:
	state = State.GAME_OVER
	print("[Game] - game over com %d pontos" % score)
	await get_tree().create_timer(1.5).timeout
	# Ignora se o jogador já saiu da tela de game over (ex.: voltou ao menu e iniciou outra partida)
	if state != State.GAME_OVER:
		return
	quit_to_menu()
