extends Node

# Player death
signal player_died()
# Last graveyard boss defeated (end of the current loop)
signal boss_defeated()
# Boss entered the arena (the boss health bar starts tracking it)
signal boss_spawned(boss: Node)
# Boss crossed a health threshold and became immune to the items of the last potion (new ones and all accumulated)
signal boss_adapted(new_items: Array[ItemData], all_immune: Array[ItemData])
# Run ended: shows the summary (victory = boss defeated, can continue to infinite mode)
signal run_ended(victory: bool)
# Player's current health changed
signal player_health_changed(current: int, max_value: int)
# Enemy defeated, grants points
signal enemy_killed(points: int)
# Score changed
signal score_changed(score: int)
# Game paused or unpaused
signal game_paused(paused: bool)
# Scene change request
signal scene_change_requested(path: String)
# Request to play a sound effect
signal play_sfx_requested(sfx_name: String)
# Request to play a music track
signal play_music_requested(music_name: String)
# Item used in the cauldron (reserved for the cauldron)
signal item_brewed(item_id: StringName)
# Active effects changed
signal active_effects_changed()
# Request to open the inventory
signal inventory_open_requested()
# Inventory closed
signal inventory_closed()
# Items on the ground changed
signal ground_items_changed()
# Monster Survivors: a wave started (number and whether it is a boss wave)
signal wave_started(wave: int, is_boss: bool)
# Monster Survivors: a wave was cleared
signal wave_cleared(wave: int)
# Monster Survivors: rest with no timer started (true) or ended (false); the next wave waits for the player.
# boss_next = the next wave is a boss wave
signal wave_rest_changed(resting: bool, boss_next: bool)
# Monster Survivors: the player asked for the next wave (HUD button during the rest)
signal next_wave_requested()
# Monster Survivors: XP orb collected (amount of XP)
signal xp_collected(amount: int)
# Monster Survivors: XP / level changed (level, xp in the level, xp needed for the next level)
signal xp_changed(level: int, xp: int, xp_needed: int)
# Monster Survivors: the player reached a new level
signal player_leveled_up(level: int)
# Item drop request (source = LootManager.Source); the LootManager rolls and drops it on the ground
signal item_drop_requested(source: int, position: Vector2)
# Item picked up from the ground
signal item_picked_up(item_id: StringName)
# Potion slots changed (contents)
signal potion_slots_changed()
# Active potion slot changed
signal potion_selected(index: int)
# Floor changed (current level)
signal floor_changed(level: int)
# Request to open the cauldron menu
signal cauldron_open_requested(cauldron: Node)
# Room changed (current room index)
signal room_changed(index: int)
# Graveyard loaded (1-based index and total graveyards)
signal cemetery_changed(index: int, total: int)
# Time left in the horde room (negative value = hide)
signal horde_timer_changed(seconds_left: float)
# Enemy died: position, was marked, is basic
signal enemy_died(position: Vector2, was_marked: bool, is_basic: bool)
# Damage-over-time tick on an enemy: source and damage dealt
signal enemy_dot_ticked(enemy: Node, source: StringName, amount: int)
# Rage (Evil synergy) changed: damage bonus (0.05 = +5%)
signal rage_changed(bonus: float)
# Charmed enemy died: the enemy (still valid during the signal) and the remaining charm time
signal charmed_enemy_died(enemy: Node2D, charm_time_left: float)

# --- Game feel (listened to by the Juice autoload, the UI and the audio) ---
# Screen shake request (trauma from 0 to 1, added to the current one)
signal screen_shake_requested(trauma: float)
# Request to freeze the game for "duration" real seconds (the largest wins, does not stack)
signal hitstop_requested(duration: float)
# Slow-motion request: time scale for "duration" real seconds
signal slowmo_requested(scale: float, duration: float)
# Direct damage dealt to an enemy (damage numbers)
signal damage_dealt(position: Vector2, amount: int, is_crit: bool, color: Color)
# Damage negated (Darkness synergy): shows "BLOCK"
signal damage_blocked(position: Vector2)
# Player took damage
signal player_hurt(position: Vector2)
# Bullet destroyed against a wall
signal bullet_hit_wall(position: Vector2, color: Color)
# Room locked / was cleared
signal room_locked()
signal room_cleared()
# Item picked up from the ground (with the position it was at)
signal item_collected(item_id: StringName, position: Vector2)
# Potion brewed in the cauldron
signal potion_brewed(color: Color, position: Vector2)
# Journal: a new entry was discovered (item or synergy)
signal compendium_updated()
# Request to open the journal
signal journal_open_requested()
# "Atmosphere effects" setting changed (night lighting, fog, particles, shadows); see AmbienceSettings
signal ambience_toggled(enabled: bool)
