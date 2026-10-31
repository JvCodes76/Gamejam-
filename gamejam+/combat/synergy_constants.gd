class_name SynergyConstants
extends RefCounted
## Constantes de balanceamento das sinergias de aspecto. Valores marcados [N] foram inventados e podem ser ajustados.

# --- Tiers: quantidade de aspectos do mesmo tipo para cada nível (cumulativos) ---
const TIER_THRESHOLDS: Array[int] = [3, 6, 9, 12]

# --- PLANT ---
# Chance de enraizar ao acertar (tier 3)
const PLANT_ROOT_CHANCE: float = 0.15
# Chance de enraizar com tier 9
const PLANT_ROOT_CHANCE_T9: float = 0.30
# Duração das raízes em segundos
const PLANT_ROOT_DURATION: float = 2.0
# [N] DoT das raízes (tier 6): fração do dano da arma por segundo
const PLANT_ROOT_DOT_FRACTION: float = 0.5
# Tick do DoT das raízes
const PLANT_ROOT_DOT_TICK: float = 0.5
# Tier 12: fração do dano de raiz causado que cura o player
const PLANT_ROOT_HEAL_FRACTION: float = 0.2

# --- POISON ---
# Tier 3: redução de velocidade do inimigo envenenado
const POISON_SLOW_FRACTION: float = 0.2
# Tier 6: bônus no DoT de veneno
const POISON_DPS_BONUS: float = 0.5
# [N] Tier 9: redução do dano causado pelo inimigo envenenado
const POISON_WEAKEN_FRACTION: float = 0.25
# Tier 12: chance por tick de veneno de matar um inimigo básico na hora
const POISON_INSTAKILL_CHANCE: float = 0.02

# --- EARTH ---
# Tier 3: redução de velocidade dentro da lama
const EARTH_MUD_SLOW: float = 0.4
# Tier 9: redução de velocidade maior
const EARTH_MUD_SLOW_T9: float = 0.6
# Tier 6: dano da lama (fração do dano da arma por segundo)
const EARTH_MUD_DPS_FRACTION: float = 1.0
# Tick de dano da lama
const EARTH_MUD_TICK: float = 0.5
# Distância entre poças ao longo da trajetória da bala (px)
const EARTH_TRAIL_SPACING: float = 14.0
# Duração de cada poça do rastro (s)
const EARTH_TRAIL_LIFETIME: float = 3.0
# Raio de cada poça do rastro (px)
const EARTH_TRAIL_RADIUS: float = 10.0
# Tier 12: poça grande ao morrer (raio px e duração s)
const EARTH_DEATH_POOL_RADIUS: float = 40.0
const EARTH_DEATH_POOL_LIFETIME: float = 4.0
# Intervalo de atualização da lama (aplica slow/dano a quem está dentro)
const EARTH_MUD_REFRESH: float = 0.2
# Cor da lama (marrom escuro semitransparente)
const EARTH_MUD_COLOR: Color = Color(0.25, 0.15, 0.07, 0.55)

# --- ROCK ---
# Chance de stun ao acertar (tier 3)
const ROCK_STUN_CHANCE: float = 0.10
# Tier 9
const ROCK_STUN_CHANCE_T9: float = 0.20
# Tier 12
const ROCK_STUN_CHANCE_T12: float = 0.30
# Tier 6: duração extra do stun (s)
const ROCK_STUN_EXTRA: float = 0.2
# Tier 6: novo teto do stun (s)
const ROCK_STUN_MAX: float = 1.0

# --- ANIMAL ---
# Intervalo de reavaliação do inimigo mais forte (s)
const ANIMAL_REEVALUATE: float = 1.0
# Duração da marca aplicada pela sinergia (renovada a cada reavaliação)
const ANIMAL_MARK_DURATION: float = 1.5
# [N] Tier 6: redução de dano dos inimigos marcados
const ANIMAL_MARKED_WEAKEN: float = 0.3
# Quantidade de marcados no tier 9
const ANIMAL_MARK_COUNT_T9: int = 2
# Tier 12: raio da explosão do marcado (px) e fração do dano da arma
const ANIMAL_EXPLOSION_RADIUS: float = 36.0
const ANIMAL_EXPLOSION_FRACTION: float = 1.0
const ANIMAL_EXPLOSION_COLOR: Color = Color(0.92, 0.28, 0.28)

# --- DARKNESS ---
# Chance de negar dano recebido (tier 3)
const DARKNESS_NEGATE_CHANCE: float = 0.10
# Tier 9
const DARKNESS_NEGATE_CHANCE_T9: float = 0.20
# Tier 6: explosão sombria ao negar
const DARKNESS_BLAST_RADIUS: float = 48.0
const DARKNESS_BLAST_FRACTION: float = 1.0
const DARKNESS_COLOR: Color = Color(0.25, 0.12, 0.45)
# Cor e duração do flash do player ao negar
const DARKNESS_FLASH_COLOR: Color = Color(0.25, 0.2, 0.45)
const DARKNESS_FLASH_TIME: float = 0.2

# --- LIGHT ---
# Chance por tiro de bala santa (tier 3)
const LIGHT_HOLY_CHANCE: float = 0.20
# Tier 9
const LIGHT_HOLY_CHANCE_T9: float = 0.35
# Dano extra da bala santa (+100%)
const LIGHT_HOLY_BONUS: float = 1.0
# Tier 6: chance por hit de bala santa de matar básicos na hora
const LIGHT_INSTAKILL_CHANCE: float = 0.15
# Cor da bala santa e da rajada de luz
const LIGHT_HOLY_COLOR: Color = Color(1.0, 0.88, 0.35)
# Raio visual da rajada de luz (px)
const LIGHT_BURST_RADIUS: float = 26.0

# --- MAGIC ---
# Distância máxima do salto do raio (px)
const MAGIC_ARC_RANGE: float = 70.0
# Fração do dano da arma causada pelo raio
const MAGIC_ARC_FRACTION: float = 1.0
# Duração visual do raio (s)
const MAGIC_ARC_TIME: float = 0.15
# Cor base do raio (misturada com a cor da poção)
const MAGIC_ARC_COLOR: Color = Color(0.7, 0.35, 1.0)
const MAGIC_ARC_WIDTH: float = 2.0

# --- EVIL ---
# Bônus de dano por inimigo morto (+0.5%)
const EVIL_RAGE_PER_KILL: float = 0.005
