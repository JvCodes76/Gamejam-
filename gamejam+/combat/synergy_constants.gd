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

# ===== SINERGIAS ESPECIAIS (receitas por ingredientes). Valores marcados [N] foram inventados. =====

# --- Salad!: bônus somado à chance de lifesteal (vale mesmo sem pontos de lifesteal) ---
const SALAD_LIFESTEAL_CHANCE: float = 0.04

# --- EVIL Salad!!: bônus somado à chance base de veneno (20%) ---
const EVIL_SALAD_POISON_CHANCE: float = 0.10

# --- Spice bag: rastro de nuvem que reduz a velocidade ---
# [N] Redução de velocidade dentro da nuvem (0.15 = -15%)
const CLOUD_SLOW: float = 0.15
# Distância entre nuvens ao longo da trajetória da bala (px)
const CLOUD_TRAIL_SPACING: float = 12.0
# Duração de cada nuvem (s)
const CLOUD_TRAIL_LIFETIME: float = 2.0
# Raio de cada nuvem (px)
const CLOUD_TRAIL_RADIUS: float = 9.0
# Intervalo de atualização da nuvem (aplica o slow a quem está dentro)
const CLOUD_REFRESH: float = 0.2
# Cor da nuvem (cinza-claro translúcido)
const CLOUD_COLOR: Color = Color(0.82, 0.82, 0.85, 0.4)

# --- Unethical Butcher :( : orbe de cura dropada por inimigo marcado ---
# [N] Chance de dropar a orbe ao morrer marcado
const BUTCHER_ORB_CHANCE: float = 0.25
# Vida curada ao coletar a orbe
const BUTCHER_ORB_HEAL: int = 1
# [N] Raio em que a orbe atrai o player (px)
const BUTCHER_ORB_ATTRACT_RADIUS: float = 40.0
# Velocidade da orbe ao ser atraída (px/s)
const BUTCHER_ORB_ATTRACT_SPEED: float = 90.0
# Tempo de vida da orbe (s)
const BUTCHER_ORB_LIFETIME: float = 8.0
# Raio de coleta (px)
const BUTCHER_ORB_PICKUP_RADIUS: float = 7.0
# Cores do brilho da orbe (verde e vermelho)
const BUTCHER_ORB_COLOR_A: Color = Color(0.35, 1.0, 0.5)
const BUTCHER_ORB_COLOR_B: Color = Color(1.0, 0.3, 0.3)

# --- Crunchy!: bônus de dano recebido por inimigos atordoados ---
# [N] +10% de dano recebido
const CRUNCHY_STUN_DAMAGE_BONUS: float = 0.10

# --- Press F to pay respects: fantasma de inimigo enfeitiçado ---
# [N] Velocidade do fantasma (px/s)
const GHOST_SPEED: float = 55.0
# [N] Dano de contato do fantasma
const GHOST_DAMAGE: int = 1
# [N] Intervalo entre golpes do mesmo fantasma (s)
const GHOST_HIT_COOLDOWN: float = 0.5
# Raio de contato do fantasma (px)
const GHOST_RADIUS: float = 10.0
# Cor/transparência do fantasma (azulado translúcido)
const GHOST_COLOR: Color = Color(0.55, 0.75, 1.0, 0.55)
# Tempo do fade final (s)
const GHOST_FADE_TIME: float = 0.5
# Tempo mínimo de charm restante para surgir um fantasma (s)
const GHOST_MIN_TIME: float = 0.1

# --- RAINBOWS!!!: bônus de charm, ricochete e cores ---
# [N] Bônus somado à chance de charm
const RAINBOW_CHARM_CHANCE: float = 0.10
# Ricochetes extras por projétil
const RAINBOW_BOUNCE_COUNT: int = 1
# Cores do arco-íris em ordem (vermelho, laranja, amarelo, verde, azul, violeta)
const RAINBOW_COLORS: Array[Color] = [
	Color(1.0, 0.15, 0.15), Color(1.0, 0.55, 0.1), Color(1.0, 0.95, 0.2),
	Color(0.2, 0.9, 0.3), Color(0.2, 0.5, 1.0), Color(0.6, 0.25, 0.9),
]
# Folga ao recuar a bala da parede após o ricochete (px)
const BOUNCE_PUSH_OUT: float = 4.0

# --- Do NOT make this tea.: ao atravessar um básico (precisa de pierce) ---
# [N] Chance de o básico perder vida na hora
const TEA_CHANCE: float = 0.10
# Fração da vida máxima perdida
const TEA_HEALTH_FRACTION: float = 0.20

# --- Weird Eye Drops.: bala se divide ao acertar ---
# Ângulo das balas filhas em relação à direção (graus)
const SPLIT_ANGLE_DEG: float = 35.0
# [N] Fração do dano das filhas
const SPLIT_DAMAGE_FRACTION: float = 0.5
# Fração do lifetime das filhas
const SPLIT_LIFETIME_FRACTION: float = 0.5

# --- Magical Potentializer: explosões maiores e mais fortes ---
# Multiplicador do raio das explosões
const POTENTIALIZER_RADIUS_MULT: float = 1.2
# Multiplicador do dano das explosões
const POTENTIALIZER_DAMAGE_MULT: float = 1.2

# ===== ANÚNCIO AO PREPARAR A POÇÃO (no caldeirão) =====
# Partículas da explosão do caldeirão (o impacto normal usa 16)
const ANNOUNCE_BURST_PARTICLES: int = 40
# Raio visual do anel da explosão (px)
const ANNOUNCE_BURST_RADIUS: float = 54.0
# Espessura do anel expansivo (px)
const ANNOUNCE_RING_WIDTH: float = 3.0
# Tempo de expansão do anel (s)
const ANNOUNCE_RING_GROW_TIME: float = 0.45
# Multiplicador da velocidade das partículas da explosão
const ANNOUNCE_BURST_SPEED_SCALE: float = 2.5
# Duração das partículas da explosão (s)
const ANNOUNCE_BURST_LIFETIME: float = 0.9
# Alfa e duração do flash branco
const ANNOUNCE_FLASH_ALPHA: float = 0.35
const ANNOUNCE_FLASH_TIME: float = 0.1
# Duração da subida do nome até o topo da tela (s)
const ANNOUNCE_FLOAT_TIME: float = 2.5
# Curva de aceleração da subida (1 = linear; maior = acelera mais)
const ANNOUNCE_ACCEL_CURVE: float = 1.4
# Fração final da subida em que o nome some (fade)
const ANNOUNCE_FADE_FRACTION: float = 0.3
# Oscilação lateral: amplitude (px) e ciclos durante a subida
const ANNOUNCE_WOBBLE_AMPLITUDE: float = 5.0
const ANNOUNCE_WOBBLE_CYCLES: float = 2.0
# Atraso entre uma sinergia e a próxima (s) e deslocamento lateral por sinergia (px)
const ANNOUNCE_STAGGER: float = 0.35
const ANNOUNCE_X_STEP: float = 70.0
# Tamanho da fonte do nome, da descrição e espessura do contorno
const ANNOUNCE_NAME_FONT_SIZE: int = 18
const ANNOUNCE_DESC_FONT_SIZE: int = 9
const ANNOUNCE_OUTLINE_SIZE: int = 5
# Cor dourada do nome (misturada com a cor da poção)
const ANNOUNCE_GOLD: Color = Color(1.0, 0.85, 0.3)
const ANNOUNCE_COLOR_MIX: float = 0.35
