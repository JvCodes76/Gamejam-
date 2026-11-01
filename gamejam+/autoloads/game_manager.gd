extends Node

enum State { MENU, PLAYING, PAUSED, GAME_OVER, VICTORY }

const LEVEL_PATH: String = "res://levels/dungeon_level.tscn"
const SURVIVORS_LEVEL_PATH: String = "res://survivors/survivors_level.tscn"
const MENU_PATH: String = "res://ui/main_menu.tscn"

## Wait (s) between the player's death and the run summary
@export var death_summary_delay: float = 1.5
## Wait (s) between the boss's death and the run summary (lets the slow-motion and the "ROOM CLEARED" play)
@export var victory_summary_delay: float = 1.8

var state: State = State.MENU
var score: int = 0
# Current room (1 = first); no triggers for now
var room_index: int = 1
# Current graveyard (1 = first) and run seed (the rooms of each graveyard derive from it)
var cemetery_index: int = 1
var run_seed: int = 0
# Infinite mode: how many times the final boss has been defeated (0 = first lap)
var loop_index: int = 0
# Accessibility: turns off screen shake
var reduce_screen_shake: bool = false
# Monster Survivors run: single arena, XP and levels instead of graveyards
var survivors_mode: bool = false
# Tutorial run: fixed rooms, no mimics, the teleporter returns to the main menu
var tutorial_mode: bool = false
# [DEBUG] Request to skip to the boss fight on the next level load (read and cleared by the DungeonLevel)
var debug_boss_requested: bool = false

# --- Run statistics (summary) ---
var kills: int = 0
var elite_kills: int = 0
var bosses_defeated: int = 0
var potions_brewed: int = 0
var items_collected: int = 0
var rooms_visited: int = 0
# Time played in real seconds (hitstop zeroes Engine.time_scale, so delta is not used)
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


## Resets the state and loads the main level (tutorial = fixed tutorial rooms instead of the dungeon).
func start_game(tutorial: bool = false, survivors: bool = false) -> void:
	tutorial_mode = tutorial
	survivors_mode = survivors
	LootManager.progress_bonus = 0
	LootManager.reset_pity()
	score = 0
	room_index = 1
	cemetery_index = 1
	loop_index = 0
	run_seed = randi()
	_reset_stats()
	ItemManager.reset()
	# The tutorial teaches the inventory: it stays locked until the first item is picked up
	ItemManager.inventory_locked = tutorial
	EventBus.score_changed.emit(score)
	state = State.PLAYING
	get_tree().paused = false
	EventBus.scene_change_requested.emit(SURVIVORS_LEVEL_PATH if survivors else LEVEL_PATH)
	print("[Game] - run started (tutorial: %s, survivors: %s)" % [tutorial, survivors])


## Advances to the next room and notifies the EventBus.
func advance_room() -> void:
	room_index += 1
	rooms_visited += 1
	print("[Game] - room %d" % room_index)
	EventBus.room_changed.emit(room_index)


## Moves to the next graveyard: items shrink, the ground is cleared and the level is generated again.
func advance_cemetery() -> void:
	cemetery_index += 1
	room_index = 1
	ItemManager.ground_entries.clear()
	ItemManager.advance_floor()
	print("[Game] - graveyard %d" % cemetery_index)
	EventBus.scene_change_requested.emit(LEVEL_PATH)


## [DEBUG] Reloads the level directly in the last graveyard, at the boss door (keeps items and potions).
func debug_go_to_boss() -> void:
	debug_boss_requested = true
	room_index = 1
	ItemManager.ground_entries.clear()
	print("[Game] - [DEBUG] skipping to the boss fight")
	EventBus.scene_change_requested.emit(LEVEL_PATH)


## Infinite mode: goes back to the first graveyard keeping items, potions and score, with stronger enemies.
func continue_endless() -> void:
	if state != State.VICTORY:
		return
	loop_index += 1
	cemetery_index = 1
	room_index = 1
	# New seed: the maps of the new lap differ from the ones already seen
	run_seed = randi()
	ItemManager.ground_entries.clear()
	ItemManager.advance_floor()
	state = State.PLAYING
	get_tree().paused = false
	print("[Game] - infinite mode: loop %d" % (loop_index + 1))
	EventBus.scene_change_requested.emit(LEVEL_PATH)


## Toggles between playing and paused. Ignored outside a run.
func toggle_pause() -> void:
	if state != State.PLAYING and state != State.PAUSED:
		return
	var paused: bool = state == State.PLAYING
	state = State.PAUSED if paused else State.PLAYING
	get_tree().paused = paused
	EventBus.game_paused.emit(paused)


## Unpauses and returns to the main menu.
func quit_to_menu() -> void:
	get_tree().paused = false
	state = State.MENU
	EventBus.game_paused.emit(false)
	EventBus.scene_change_requested.emit(MENU_PATH)


## Restarts the current run (used after game over); a tutorial restarts as a tutorial.
func restart() -> void:
	start_game(tutorial_mode, survivors_mode)


## Tutorial teleporter: goes back to the main menu.
func finish_tutorial() -> void:
	print("[Game] - tutorial finished")
	tutorial_mode = false
	ItemManager.inventory_locked = false
	quit_to_menu()


# Resets the counters shown in the run summary
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


# Counts kills for the summary (elites and the boss are not basic)
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
	print("[Game] - game over with %d points (loop %d)" % [score, loop_index + 1])
	await get_tree().create_timer(death_summary_delay, true, false, true).timeout
	# Ignored if the player has already left the game over screen (e.g. went back to the menu and started another run)
	if state != State.GAME_OVER:
		return
	get_tree().paused = true
	EventBus.run_ended.emit(false)


# Final boss defeated: closes the current loop and offers to end the run or continue in infinite mode
func _on_boss_defeated() -> void:
	# Monster Survivors has no ending: bosses are just milestones of the waves
	if state != State.PLAYING or survivors_mode:
		return
	state = State.VICTORY
	bosses_defeated += 1
	print("[Game] - boss defeated (loop %d)" % (loop_index + 1))
	await get_tree().create_timer(victory_summary_delay, true, false, true).timeout
	if state != State.VICTORY:
		return
	get_tree().paused = true
	EventBus.run_ended.emit(true)
