class_name FeelConstants
extends RefCounted
## Game feel constants (shake, hitstop, slow-motion, flashes, damage numbers) in a single place.
## Per-entity values (knockback resistance, i-frames...) live in @export on the scenes themselves.

# --- Trauma-based screen shake: offset = trauma² * amplitude, with noise; trauma decays per second ---
const SHAKE_MAX_OFFSET: float = 10.0
const SHAKE_MAX_ROTATION: float = 0.04
const SHAKE_DECAY: float = 1.6
const SHAKE_NOISE_SPEED: float = 60.0

# --- Hitstop (ms) ---
const HITSTOP_CRIT_MS: float = 30.0
const HITSTOP_ELITE_DEATH_MS: float = 40.0
const HITSTOP_PLAYER_HURT_MS: float = 70.0
# Multi-kill: N kills within the window trigger hitstop
const MULTI_KILL_COUNT: int = 3
const MULTI_KILL_WINDOW_MS: float = 120.0
# Time the slow-motion takes to return to 1.0 (real s)
const SLOWMO_RECOVER: float = 0.25

# --- Trauma per event ---
const TRAUMA_CRIT: float = 0.1
const TRAUMA_BASIC_DEATH: float = 0.15
const TRAUMA_ELITE_DEATH: float = 0.5
const TRAUMA_PLAYER_HURT: float = 0.4
const TRAUMA_PLAYER_DEATH: float = 0.7
const TRAUMA_SPAWN: float = 0.05
const TRAUMA_ROOM_LOCK: float = 0.2
const TRAUMA_MIMIC_WAKE: float = 0.3
const TRAUMA_BREW: float = 0.15

# --- Camera ---
const CAMERA_SMOOTHING_SPEED: float = 9.0
const CAMERA_LOOK_AHEAD: float = 0.25
const CAMERA_LOOK_AHEAD_MAX: float = 40.0
const CAMERA_LOOK_AHEAD_LERP: float = 8.0
const CAMERA_RECOIL: float = 2.0
const CAMERA_RECOIL_DECAY: float = 30.0

# --- Flash and squash (shader res://assets/shaders/flash.gdshader) ---
const FLASH_TIME: float = 0.08
const FLASH_HURT_COLOR: Color = Color(1.0, 0.15, 0.15)
const SQUASH_SCALE: Vector2 = Vector2(1.25, 0.8)
const SQUASH_TIME: float = 0.12

# --- Knockback (impulse in px/s and friction in px/s²) ---
const KNOCKBACK_IMPULSE: float = 140.0
const KNOCKBACK_FRICTION: float = 900.0
const PLAYER_KNOCKBACK_IMPULSE: float = 170.0
const ELITE_KNOCKBACK_RESISTANCE: float = 0.7

# --- Enemy death ---
const DEATH_POP_TIME: float = 0.15
const DEATH_POP_SCALE: float = 1.35
const DEATH_PARTICLES: int = 14
const DEATH_CHUNKS: int = 6
const DEATH_CHUNK_SIZE: int = 5

# --- Player ---
const PLAYER_BLINK_INTERVAL: float = 0.06
const PLAYER_DEATH_SLOWMO: float = 0.2
const PLAYER_DEATH_SLOWMO_TIME: float = 0.6
const PLAYER_CORPSE_TIME: float = 1.0

# --- Shot ---
const MUZZLE_FLASH_FRAMES: int = 2
const SPRITE_RECOIL: float = 1.5
const SPRITE_RECOIL_TIME: float = 0.05
const BULLET_SPAWN_SCALE: float = 1.5
const BULLET_SPAWN_TIME: float = 0.05
const BULLET_TRAIL_POINTS: int = 6
const BULLET_TRAIL_WIDTH: float = 2.0

# --- Damage numbers ---
const DAMAGE_NUMBER_POOL: int = 30
const DAMAGE_NUMBER_LIFETIME: float = 0.6
const DAMAGE_NUMBER_FONT_SIZE: int = 8
const DAMAGE_NUMBER_CRIT_FONT_SIZE: int = 12
const DAMAGE_NUMBER_DOT_FONT_SIZE: int = 6
const DAMAGE_NUMBER_RISE: float = 70.0
const DAMAGE_NUMBER_GRAVITY: float = 160.0
const DAMAGE_NUMBER_SPREAD: float = 18.0
const DAMAGE_NUMBER_COLOR: Color = Color(1.0, 1.0, 1.0)
const DAMAGE_NUMBER_CRIT_COLOR: Color = Color(1.0, 0.75, 0.15)
const DAMAGE_NUMBER_BLOCK_COLOR: Color = Color(0.6, 0.6, 0.6)
# DoT ticks from the same source on the same enemy add to the still-visible number (age below the window)
const DOT_GROUP_WINDOW: float = 0.55
const DOT_COLORS: Dictionary = {
	&"poison": Color(0.45, 1.0, 0.35),
	&"fire": Color(1.0, 0.5, 0.15),
	&"roots": Color(0.65, 0.45, 0.2),
	&"mud": Color(0.55, 0.4, 0.25),
}

# --- Enemy spawn ---
const SPAWN_WARNING_TIME: float = 0.5
const SPAWN_POP_TIME: float = 0.18
const SPAWN_GRACE: float = 0.3

# --- Rooms ---
const ROOM_CLEAR_SLOWMO: float = 0.3
const ROOM_CLEAR_SLOWMO_TIME: float = 0.4
const HORDE_WARNING_SECONDS: float = 5.0

# --- Audio ---
const SFX_PITCH_VARIATION: float = 0.08
const SFX_MAX_PER_FRAME: int = 2
const MUSIC_DUCK_DB: float = -10.0
const MUSIC_DUCK_TIME: float = 0.2
