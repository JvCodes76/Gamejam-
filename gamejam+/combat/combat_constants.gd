class_name CombatConstants
extends RefCounted
## Todas as constantes de balanceamento de combate num único lugar.

# --- Escalas por ponto de efeito ("+" = 1.0) ---
const DAMAGE_PER_POINT: float = 0.25
const RANGE_PER_POINT: float = 0.25
const FIRE_RATE_PER_POINT: float = 0.25
const FIRE_DPS_PER_POINT: float = 1.5
const FIRE_DURATION: float = 2.0
const FIRE_TICK: float = 0.5

# --- Crítico: chance = base + por_luck * luck; mult = base + por_ponto * CRIT_DAMAGE ---
const CRIT_BASE_CHANCE: float = 0.05
const CRIT_CHANCE_PER_LUCK: float = 0.10
const CRIT_BASE_MULTIPLIER: float = 2.0
const CRIT_MULT_PER_POINT: float = 0.5

# --- Lifesteal: chance = ESCALA * ln(1+lifesteal) * (1+ln(1+luck)); cura = max(1% dano, 1% vida máx) ---
const LIFESTEAL_CHANCE_SCALE: float = 0.35
const LIFESTEAL_HEAL_FRACTION: float = 0.01

# --- Veneno: precisa de ingrediente POISON; dps = dano_base * (1 + POR_PONTO * POISON_DAMAGE) ---
const POISON_HIT_CHANCE: float = 0.20
const POISON_DURATION: float = 3.0
const POISON_TICK: float = 1.0
const POISON_DPS_BONUS_PER_POINT: float = 0.5

# --- Pierce: base 1 = a bala para no primeiro inimigo; pierce_count = inimigos EXTRA atravessados ---

# --- Enfeitiçar: chance = CHARM_PER_POINT * CHARM_CHANCE * (1 + ln(1+luck)) ---
const CHARM_PER_POINT: float = 0.08
const CHARM_DURATION: float = 4.0
const CHARM_TINT: Color = Color(1.0, 0.5, 0.85)
const CHARM_TINT_AMOUNT: float = 0.5

# --- Status de inimigo ---
const SLOW_FACTOR: float = 0.3
const STUN_BASE: float = 0.5
const STUN_MAX: float = 0.8
const STUN_PER_LEVEL: float = 0.1
const MARKED_DAMAGE_BONUS: float = 0.5
const MARKED_DURATION: float = 8.0
const ROOTS_DEFAULT_DURATION: float = 2.0
const SLOW_DEFAULT_DURATION: float = 2.0

# --- Arma: dano base do player (igual ao Bullet.damage da cena); base de explosões e DoTs das sinergias ---
const WEAPON_BASE_DAMAGE: int = 1

# --- Área de impacto: raio = base * range_multiplier ---
const IMPACT_RADIUS_BASE: float = 28.0

# --- Alturas (px acima dos pés): os atores ficam com a origem nos pés, a mira sai do corpo ---
const BODY_HEIGHT: float = 25.0
# Centro do corpo de um inimigo em relação aos pés (arcos mágicos ligam os corpos)
const ENEMY_BODY_OFFSET: Vector2 = Vector2(0.0, -14.0)

# --- Camadas de render (z_index): chão < decalques < itens < lama < nuvem < atores (y-sort, z 0) < projéteis < efeitos ---
const Z_GROUND_ITEM: int = -3
const Z_MUD: int = -2
const Z_CLOUD: int = -1
const Z_BULLET: int = 10
const Z_IMPACT: int = 11
const Z_ARC: int = 12
