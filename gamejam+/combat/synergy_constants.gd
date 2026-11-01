class_name SynergyConstants
extends RefCounted
## Balancing constants for the aspect synergies. Values marked [N] were made up and can be adjusted.

# --- Tiers: number of aspects of the same type for each level (cumulative) ---
const TIER_THRESHOLDS: Array[int] = [3, 6, 9, 12]

# --- PLANT ---
# Chance to root on hit (tier 3)
const PLANT_ROOT_CHANCE: float = 0.15
# Chance to root at tier 9
const PLANT_ROOT_CHANCE_T9: float = 0.30
# Root duration in seconds
const PLANT_ROOT_DURATION: float = 2.0
# [N] Root DoT (tier 6): fraction of the weapon damage per second
const PLANT_ROOT_DOT_FRACTION: float = 0.5
# Root DoT tick
const PLANT_ROOT_DOT_TICK: float = 0.5
# Tier 12: fraction of the root damage dealt that heals the player
const PLANT_ROOT_HEAL_FRACTION: float = 0.2

# --- POISON ---
# Tier 3: speed reduction of the poisoned enemy
const POISON_SLOW_FRACTION: float = 0.2
# Tier 6: bonus to the poison DoT
const POISON_DPS_BONUS: float = 0.5
# [N] Tier 9: reduction of the damage dealt by the poisoned enemy
const POISON_WEAKEN_FRACTION: float = 0.25
# Tier 12: chance per poison tick of instantly killing a basic enemy
const POISON_INSTAKILL_CHANCE: float = 0.02

# --- EARTH ---
# Tier 3: speed reduction inside the mud
const EARTH_MUD_SLOW: float = 0.4
# Tier 9: larger speed reduction
const EARTH_MUD_SLOW_T9: float = 0.6
# Tier 6: mud damage (fraction of the weapon damage per second)
const EARTH_MUD_DPS_FRACTION: float = 1.0
# Mud damage tick
const EARTH_MUD_TICK: float = 0.5
# Distance between puddles along the bullet path (px)
const EARTH_TRAIL_SPACING: float = 14.0
# Duration of each trail puddle (s)
const EARTH_TRAIL_LIFETIME: float = 3.0
# Radius of each trail puddle (px)
const EARTH_TRAIL_RADIUS: float = 10.0
# Tier 12: large puddle on death (radius px and duration s)
const EARTH_DEATH_POOL_RADIUS: float = 40.0
const EARTH_DEATH_POOL_LIFETIME: float = 4.0
# Mud update interval (applies slow/damage to anyone inside)
const EARTH_MUD_REFRESH: float = 0.2
# Mud color (semi-transparent dark brown)
const EARTH_MUD_COLOR: Color = Color(0.25, 0.15, 0.07, 0.55)

# --- ROCK ---
# Chance to stun on hit (tier 3)
const ROCK_STUN_CHANCE: float = 0.10
# Tier 9
const ROCK_STUN_CHANCE_T9: float = 0.20
# Tier 12
const ROCK_STUN_CHANCE_T12: float = 0.30
# Tier 6: extra stun duration (s)
const ROCK_STUN_EXTRA: float = 0.2
# Tier 6: new stun cap (s)
const ROCK_STUN_MAX: float = 1.0

# --- ANIMAL ---
# Re-evaluation interval of the strongest enemy (s)
const ANIMAL_REEVALUATE: float = 1.0
# Duration of the mark applied by the synergy (renewed on every re-evaluation)
const ANIMAL_MARK_DURATION: float = 1.5
# [N] Tier 6: damage reduction of marked enemies
const ANIMAL_MARKED_WEAKEN: float = 0.3
# Number of marked enemies at tier 9
const ANIMAL_MARK_COUNT_T9: int = 2
# Tier 12: explosion radius of the marked enemy (px) and fraction of the weapon damage
const ANIMAL_EXPLOSION_RADIUS: float = 36.0
const ANIMAL_EXPLOSION_FRACTION: float = 1.0
const ANIMAL_EXPLOSION_COLOR: Color = Color(0.92, 0.28, 0.28)

# --- DARKNESS ---
# Chance to negate incoming damage (tier 3)
const DARKNESS_NEGATE_CHANCE: float = 0.10
# Tier 9
const DARKNESS_NEGATE_CHANCE_T9: float = 0.20
# Tier 6: dark explosion on negation
const DARKNESS_BLAST_RADIUS: float = 48.0
const DARKNESS_BLAST_FRACTION: float = 1.0
const DARKNESS_COLOR: Color = Color(0.25, 0.12, 0.45)
# Color and duration of the player's flash on negation
const DARKNESS_FLASH_COLOR: Color = Color(0.25, 0.2, 0.45)
const DARKNESS_FLASH_TIME: float = 0.2

# --- LIGHT ---
# Chance per shot of a holy bullet (tier 3)
const LIGHT_HOLY_CHANCE: float = 0.20
# Tier 9
const LIGHT_HOLY_CHANCE_T9: float = 0.35
# Extra damage of the holy bullet (+100%)
const LIGHT_HOLY_BONUS: float = 1.0
# Tier 6: chance per holy bullet hit of instantly killing basic enemies
const LIGHT_INSTAKILL_CHANCE: float = 0.15
# Color of the holy bullet and the light burst
const LIGHT_HOLY_COLOR: Color = Color(1.0, 0.88, 0.35)
# Visual radius of the light burst (px)
const LIGHT_BURST_RADIUS: float = 26.0

# --- MAGIC ---
# Maximum jump distance of the bolt (px)
const MAGIC_ARC_RANGE: float = 70.0
# Fraction of the weapon damage dealt by the bolt
const MAGIC_ARC_FRACTION: float = 1.0
# Visual duration of the bolt (s)
const MAGIC_ARC_TIME: float = 0.15
# Base color of the bolt (blended with the potion color)
const MAGIC_ARC_COLOR: Color = Color(0.7, 0.35, 1.0)
const MAGIC_ARC_WIDTH: float = 2.0

# --- EVIL ---
# Damage bonus per enemy killed (+0.5%)
const EVIL_RAGE_PER_KILL: float = 0.005

# ===== SPECIAL SYNERGIES (ingredient recipes). Values marked [N] were made up. =====

# --- Salad!: bonus added to the lifesteal chance (applies even without lifesteal points) ---
const SALAD_LIFESTEAL_CHANCE: float = 0.04

# --- EVIL Salad!!: bonus added to the base poison chance (20%) ---
const EVIL_SALAD_POISON_CHANCE: float = 0.10

# --- Spice bag: cloud trail that reduces speed ---
# [N] Speed reduction inside the cloud (0.15 = -15%)
const CLOUD_SLOW: float = 0.15
# Distance between clouds along the bullet path (px)
const CLOUD_TRAIL_SPACING: float = 12.0
# Duration of each cloud (s)
const CLOUD_TRAIL_LIFETIME: float = 2.0
# Radius of each cloud (px)
const CLOUD_TRAIL_RADIUS: float = 9.0
# Cloud update interval (applies the slow to anyone inside)
const CLOUD_REFRESH: float = 0.2
# Cloud color (translucent light gray)
const CLOUD_COLOR: Color = Color(0.82, 0.82, 0.85, 0.4)

# --- Unethical Butcher :( : higher chance of enemies dropping items and healing orbs ---
# [N] Chance of any dying enemy dropping the orb
const BUTCHER_ORB_CHANCE: float = 0.15
# [N] Multiplier on the item drop chance of regular and elite enemies
const BUTCHER_DROP_CHANCE_MULT: float = 1.5
# Health healed on collecting the orb
const BUTCHER_ORB_HEAL: int = 15
# [N] Radius at which the orb attracts the player (px)
const BUTCHER_ORB_ATTRACT_RADIUS: float = 40.0
# Orb speed when attracted (px/s)
const BUTCHER_ORB_ATTRACT_SPEED: float = 90.0
# Orb lifetime (s)
const BUTCHER_ORB_LIFETIME: float = 8.0
# Collection radius (px)
const BUTCHER_ORB_PICKUP_RADIUS: float = 7.0
# Orb glow colors (green and red)
const BUTCHER_ORB_COLOR_A: Color = Color(0.35, 1.0, 0.5)
const BUTCHER_ORB_COLOR_B: Color = Color(1.0, 0.3, 0.3)

# --- Crunchy!: bonus damage taken by stunned enemies ---
# [N] +10% damage taken
const CRUNCHY_STUN_DAMAGE_BONUS: float = 0.10

# --- Press F to pay respects: ghost of a charmed enemy ---
# [N] Ghost speed (px/s)
const GHOST_SPEED: float = 55.0
# [N] Ghost contact damage
const GHOST_DAMAGE: int = 15
# [N] Interval between hits from the same ghost (s)
const GHOST_HIT_COOLDOWN: float = 0.5
# Ghost contact radius (px)
const GHOST_RADIUS: float = 10.0
# Ghost color/transparency (translucent bluish)
const GHOST_COLOR: Color = Color(0.55, 0.75, 1.0, 0.55)
# Final fade time (s)
const GHOST_FADE_TIME: float = 0.5
# Minimum remaining charm time for a ghost to appear (s)
const GHOST_MIN_TIME: float = 0.1

# --- RAINBOWS!!!: charm bonus, bounce and colors ---
# [N] Bonus added to the charm chance
const RAINBOW_CHARM_CHANCE: float = 0.10
# Extra bounces per projectile
const RAINBOW_BOUNCE_COUNT: int = 1
# Rainbow colors in order (red, orange, yellow, green, blue, violet)
const RAINBOW_COLORS: Array[Color] = [
	Color(1.0, 0.15, 0.15), Color(1.0, 0.55, 0.1), Color(1.0, 0.95, 0.2),
	Color(0.2, 0.9, 0.3), Color(0.2, 0.5, 1.0), Color(0.6, 0.25, 0.9),
]

# --- Do NOT make this tea.: when piercing a basic enemy (needs pierce) ---
# [N] Chance of the basic enemy losing health instantly
const TEA_CHANCE: float = 0.10
# Fraction of max health lost
const TEA_HEALTH_FRACTION: float = 0.20

# --- Weird Eye Drops.: bullet splits on hit ---
# Angle of the child bullets relative to the direction (degrees)
const SPLIT_ANGLE_DEG: float = 35.0
# [N] Fraction of the children's damage
const SPLIT_DAMAGE_FRACTION: float = 0.5
# Fraction of the children's lifetime
const SPLIT_LIFETIME_FRACTION: float = 0.5

# --- Magical Potentializer: bigger and stronger explosions ---
# Explosion radius multiplier
const POTENTIALIZER_RADIUS_MULT: float = 1.2
# Explosion damage multiplier
const POTENTIALIZER_DAMAGE_MULT: float = 1.2

# ===== ANNOUNCEMENT WHEN BREWING THE POTION (in the cauldron) =====
# Cauldron explosion particles (the normal impact uses 16)
const ANNOUNCE_BURST_PARTICLES: int = 40
# Visual radius of the explosion ring (px)
const ANNOUNCE_BURST_RADIUS: float = 54.0
# Thickness of the expanding ring (px)
const ANNOUNCE_RING_WIDTH: float = 3.0
# Ring expansion time (s)
const ANNOUNCE_RING_GROW_TIME: float = 0.45
# Explosion particle speed multiplier
const ANNOUNCE_BURST_SPEED_SCALE: float = 2.5
# Explosion particle duration (s)
const ANNOUNCE_BURST_LIFETIME: float = 0.9
# Alpha and duration of the white flash
const ANNOUNCE_FLASH_ALPHA: float = 0.35
const ANNOUNCE_FLASH_TIME: float = 0.1
# Duration of the name rising to the top of the screen (s)
const ANNOUNCE_FLOAT_TIME: float = 5.0
# Acceleration curve of the rise (1 = linear; higher = accelerates more)
const ANNOUNCE_ACCEL_CURVE: float = 1.4
# Final fraction of the rise during which the name fades out
const ANNOUNCE_FADE_FRACTION: float = 0.3
# Lateral wobble: amplitude (px) and cycles during the rise
const ANNOUNCE_WOBBLE_AMPLITUDE: float = 5.0
const ANNOUNCE_WOBBLE_CYCLES: float = 2.0
# Delay between one synergy and the next (s) and lateral offset per synergy (px)
const ANNOUNCE_STAGGER: float = 0.35
const ANNOUNCE_X_STEP: float = 70.0
# Font size of the name and description, and outline thickness
const ANNOUNCE_NAME_FONT_SIZE: int = 18
const ANNOUNCE_DESC_FONT_SIZE: int = 9
const ANNOUNCE_OUTLINE_SIZE: int = 5
# Golden name color (blended with the potion color)
const ANNOUNCE_GOLD: Color = Color(1.0, 0.85, 0.3)
const ANNOUNCE_COLOR_MIX: float = 0.35
