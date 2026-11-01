class_name CombatConstants
extends RefCounted
## All combat balancing constants in a single place.

# --- Scales per effect point ("+" = 1.0) ---
const DAMAGE_PER_POINT: float = 0.25
const RANGE_PER_POINT: float = 0.25
const FIRE_RATE_PER_POINT: float = 0.25
const FIRE_DPS_PER_POINT: float = 22.5
const FIRE_DURATION: float = 2.0
const FIRE_TICK: float = 0.5

# --- Critical: chance = base + per_luck * luck; mult = base + per_point * CRIT_DAMAGE ---
const CRIT_BASE_CHANCE: float = 0.05
const CRIT_CHANCE_PER_LUCK: float = 0.10
const CRIT_BASE_MULTIPLIER: float = 2.0
const CRIT_MULT_PER_POINT: float = 0.5

# --- Lifesteal: chance = SCALE * ln(1+lifesteal) * (1+ln(1+luck)); heal = max(1% damage, 1% max health) ---
const LIFESTEAL_CHANCE_SCALE: float = 0.35
const LIFESTEAL_HEAL_FRACTION: float = 0.01

# --- Poison: needs a POISON ingredient; dps = base_damage * (1 + PER_POINT * POISON_DAMAGE); stacks (each stack adds its dps, refreshes the duration) ---
const POISON_HIT_CHANCE: float = 0.20
const POISON_DURATION: float = 4.0
const POISON_TICK: float = 1.0
const POISON_DPS_BONUS_PER_POINT: float = 0.5
const POISON_MAX_STACKS: int = 8

# --- Pierce: base 1 = the bullet stops at the first enemy; pierce_count = EXTRA enemies pierced ---

# --- Charm: chance = CHARM_PER_POINT * CHARM_CHANCE * (1 + ln(1+luck)) ---
const CHARM_PER_POINT: float = 0.08
const CHARM_DURATION: float = 4.0
const CHARM_TINT: Color = Color(1.0, 0.5, 0.85)
const CHARM_TINT_AMOUNT: float = 0.5

# --- Explosive: the shot explodes when it hits an enemy (fraction of the bullet damage) ---
const EXPLOSIVE_FRACTION: float = 0.4

# --- AOE: aura around the bullet; radius = AOE_RADIUS_PER_POINT * AOE, damage per tick = fraction of the weapon damage ---
const AOE_RADIUS_PER_POINT: float = 18.0
const AOE_TICK: float = 0.15
const AOE_TICK_FRACTION: float = 0.3

# --- Homing: steering of the bullet toward the nearest enemy ---
const HOMING_RANGE: float = 150.0
const HOMING_TURN_RATE_PER_POINT: float = 4.0

# --- Bounce: after hitting (and with no pierce left) the bullet jumps to another enemy within this range ---
const BOUNCE_RANGE: float = 160.0
# Fraction of the bullet lifetime that is refunded on each bounce
const BOUNCE_LIFETIME_REFUND: float = 0.5

# --- Split: children per split point; fraction of damage and angle live in SynergyConstants ---

# --- Poison cloud (Deathcap): cloud left on the poisoned enemy; radius = RADIUS_PER_POINT * POISON_CLOUD ---
const POISON_CLOUD_RADIUS_PER_POINT: float = 24.0
const POISON_CLOUD_LIFETIME: float = 3.0
const POISON_CLOUD_TICK: float = 0.5
const POISON_CLOUD_COLOR: Color = Color(0.55, 0.85, 0.25, 0.35)

# --- Laser (Brimstone): charge, then a beam deals 100% of the weapon damage per tick ---
const LASER_CHARGE_TIME: float = 0.6
const LASER_DURATION: float = 0.5
const LASER_TICK: float = 0.1
const LASER_RANGE: float = 220.0
const LASER_WIDTH: float = 6.0
const LASER_FRACTION: float = 1.0

# --- Fire breath (Dragon's Blood): damage x2; flames are fired FLAME_RATE_DIVISOR times faster, each with 1/DIVISOR of the damage ---
const FIRE_BREATH_DAMAGE_MULT: float = 2.0
const FLAME_RATE_DIVISOR: float = 4.0
const FLAME_SPEED: float = 170.0
const FLAME_LIFETIME: float = 0.35
const FLAME_SPREAD_DEG: float = 14.0
const FLAME_COLOR: Color = Color(1.0, 0.4, 0.05)
const FLAME_PIERCE: int = 99

# --- Real bullets (Gun): damage x3, faster bullets, magazine and reload ---
const REAL_BULLETS_DAMAGE_MULT: float = 3.0
const REAL_BULLET_SPEED_MULT: float = 1.7
const MAGAZINE_SIZE: int = 6
const RELOAD_TIME: float = 1.6

# --- Enemy status ---
const SLOW_FACTOR: float = 0.3
const STUN_BASE: float = 0.5
const STUN_MAX: float = 0.8
const STUN_PER_LEVEL: float = 0.1
const MARKED_DAMAGE_BONUS: float = 0.5
const MARKED_DURATION: float = 8.0
const ROOTS_DEFAULT_DURATION: float = 2.0
const SLOW_DEFAULT_DURATION: float = 2.0

# --- Weapon: player base damage (same as the scene's Bullet.damage); base for explosions and synergy DoTs ---
const WEAPON_BASE_DAMAGE: int = 15

# --- Health scale: all health and damage were multiplied by this (1 HUD block = this much health) ---
const HEALTH_SCALE: int = 15

# --- Impact area: radius = base * range_multiplier ---
const IMPACT_RADIUS_BASE: float = 28.0

# --- Heights (px above the feet): actors have their origin at the feet, aiming comes from the body ---
const BODY_HEIGHT: float = 25.0
# Center of an enemy's body relative to the feet (magic arcs connect the bodies)
const ENEMY_BODY_OFFSET: Vector2 = Vector2(0.0, -14.0)

# --- Render layers (z_index): ground < decals < items < mud < cloud < actors (y-sort, z 0) < projectiles < effects ---
const Z_GROUND_ITEM: int = -3
const Z_MUD: int = -2
const Z_CLOUD: int = -1
const Z_BULLET: int = 10
const Z_IMPACT: int = 11
const Z_ARC: int = 12
