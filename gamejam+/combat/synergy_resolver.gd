class_name SynergyResolver
extends RefCounted
## Converte aspect_counts da poção em um SynergyState (tiers cumulativos 3/6/9/12).

const A = ItemEnums.Aspect


## Tier (0 a 4) para uma contagem de aspectos.
static func tier_of(count: int) -> int:
	var tier: int = 0
	for threshold: int in SynergyConstants.TIER_THRESHOLDS:
		if count >= threshold:
			tier += 1
	return tier


## Resolve o estado de sinergias a partir de Aspect -> int.
static func resolve(aspect_counts: Dictionary) -> SynergyState:
	var s: SynergyState = SynergyState.new()
	for aspect: int in ItemEnums.Aspect.values():
		s.tiers[aspect] = tier_of(int(aspect_counts.get(aspect, 0)))
	var t: int
	# PLANT
	t = s.tier(A.PLANT)
	if t >= 1:
		s.root_chance = SynergyConstants.PLANT_ROOT_CHANCE
		s.root_duration = SynergyConstants.PLANT_ROOT_DURATION
	if t >= 2:
		s.root_dot_fraction = SynergyConstants.PLANT_ROOT_DOT_FRACTION
	if t >= 3:
		s.root_chance = SynergyConstants.PLANT_ROOT_CHANCE_T9
	if t >= 4:
		s.root_heal_fraction = SynergyConstants.PLANT_ROOT_HEAL_FRACTION
	# POISON
	t = s.tier(A.POISON)
	if t >= 1:
		s.poison_slow = SynergyConstants.POISON_SLOW_FRACTION
	if t >= 2:
		s.poison_dps_bonus = SynergyConstants.POISON_DPS_BONUS
	if t >= 3:
		s.poison_weaken = SynergyConstants.POISON_WEAKEN_FRACTION
	if t >= 4:
		s.poison_instakill_chance = SynergyConstants.POISON_INSTAKILL_CHANCE
	# EARTH
	t = s.tier(A.EARTH)
	if t >= 1:
		s.mud_enabled = true
		s.mud_slow = SynergyConstants.EARTH_MUD_SLOW
	if t >= 2:
		s.mud_dps_fraction = SynergyConstants.EARTH_MUD_DPS_FRACTION
	if t >= 3:
		s.mud_slow = SynergyConstants.EARTH_MUD_SLOW_T9
	if t >= 4:
		s.mud_death_pool = true
	# ROCK
	t = s.tier(A.ROCK)
	if t >= 1:
		s.stun_chance = SynergyConstants.ROCK_STUN_CHANCE
	if t >= 2:
		s.stun_extra = SynergyConstants.ROCK_STUN_EXTRA
		s.stun_max = SynergyConstants.ROCK_STUN_MAX
	if t >= 3:
		s.stun_chance = SynergyConstants.ROCK_STUN_CHANCE_T9
	if t >= 4:
		s.stun_chance = SynergyConstants.ROCK_STUN_CHANCE_T12
	# ANIMAL
	t = s.tier(A.ANIMAL)
	if t >= 1:
		s.mark_count = 1
	if t >= 2:
		s.marked_weaken = SynergyConstants.ANIMAL_MARKED_WEAKEN
	if t >= 3:
		s.mark_count = SynergyConstants.ANIMAL_MARK_COUNT_T9
	if t >= 4:
		s.marked_explode = true
	# DARKNESS
	t = s.tier(A.DARKNESS)
	if t >= 1:
		s.negate_chance = SynergyConstants.DARKNESS_NEGATE_CHANCE
	if t >= 2:
		s.negate_blast = true
	if t >= 3:
		s.negate_chance = SynergyConstants.DARKNESS_NEGATE_CHANCE_T9
	# LIGHT
	t = s.tier(A.LIGHT)
	if t >= 1:
		s.holy_chance = SynergyConstants.LIGHT_HOLY_CHANCE
	if t >= 2:
		s.holy_instakill_chance = SynergyConstants.LIGHT_INSTAKILL_CHANCE
	if t >= 3:
		s.holy_chance = SynergyConstants.LIGHT_HOLY_CHANCE_T9
	# MAGIC
	t = s.tier(A.MAGIC)
	s.arc_enabled = t >= 1
	s.arc_bounce = t >= 2
	# EVIL
	t = s.tier(A.EVIL)
	s.rage_enabled = t >= 1
	s.rage_resets_per_floor = t >= 2
	return s


## Linhas legíveis (inglês) das sinergias ativas, p.ex. "Poison (6): poison slows by 20%, deals +50% damage".
static func describe(aspect_counts: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = PackedStringArray()
	for aspect: int in ItemEnums.Aspect.values():
		var count: int = int(aspect_counts.get(aspect, 0))
		var tier: int = tier_of(count)
		if tier <= 0:
			continue
		var parts: PackedStringArray = PackedStringArray()
		var texts: Array = _tier_texts(aspect)
		for i: int in tier:
			if String(texts[i]) != "":
				parts.append(TranslationServer.translate(texts[i]))
		lines.append("%s (%d): %s" % [_aspect_name(aspect), count, ", ".join(parts)])
	return lines


## Resumo curto para log, p.ex. "Poison 6, Plant 3" (vazio se nada ativo).
static func summary(aspect_counts: Dictionary) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for aspect: int in ItemEnums.Aspect.values():
		var count: int = int(aspect_counts.get(aspect, 0))
		if tier_of(count) > 0:
			parts.append("%s %d" % [_aspect_name(aspect), count])
	return ", ".join(parts)


static func _aspect_name(aspect: int) -> String:
	return String(ItemEnums.Aspect.keys()[aspect]).capitalize()


## Textos por tier (índice 0 = tier 3, 3 = tier 12) de um aspecto.
static func _tier_texts(aspect: int) -> Array:
	match aspect:
		A.PLANT:
			return [
				"hits may root enemies (%d%%)" % roundi(SynergyConstants.PLANT_ROOT_CHANCE * 100.0),
				"rooted enemies take damage over time",
				"higher root chance (%d%%)" % roundi(SynergyConstants.PLANT_ROOT_CHANCE_T9 * 100.0),
				"root damage heals you (%d%%)" % roundi(SynergyConstants.PLANT_ROOT_HEAL_FRACTION * 100.0),
			]
		A.POISON:
			return [
				"poison slows by %d%%" % roundi(SynergyConstants.POISON_SLOW_FRACTION * 100.0),
				"deals +%d%% damage" % roundi(SynergyConstants.POISON_DPS_BONUS * 100.0),
				"poisoned enemies deal %d%% less damage" % roundi(SynergyConstants.POISON_WEAKEN_FRACTION * 100.0),
				"%d%% chance per tick to kill basic enemies" % roundi(SynergyConstants.POISON_INSTAKILL_CHANCE * 100.0),
			]
		A.EARTH:
			return [
				"bullets leave a mud trail (-%d%% speed)" % roundi(SynergyConstants.EARTH_MUD_SLOW * 100.0),
				"mud deals damage",
				"mud slows by %d%%" % roundi(SynergyConstants.EARTH_MUD_SLOW_T9 * 100.0),
				"enemies burst into mud when they die",
			]
		A.ROCK:
			return [
				"hits may stun (%d%%)" % roundi(SynergyConstants.ROCK_STUN_CHANCE * 100.0),
				"stuns last longer",
				"stun chance %d%%" % roundi(SynergyConstants.ROCK_STUN_CHANCE_T9 * 100.0),
				"stun chance %d%%" % roundi(SynergyConstants.ROCK_STUN_CHANCE_T12 * 100.0),
			]
		A.ANIMAL:
			return [
				"the strongest enemy is marked",
				"marked enemies deal %d%% less damage" % roundi(SynergyConstants.ANIMAL_MARKED_WEAKEN * 100.0),
				"two enemies can be marked",
				"marked enemies explode on death",
			]
		A.DARKNESS:
			return [
				"%d%% chance to negate damage" % roundi(SynergyConstants.DARKNESS_NEGATE_CHANCE * 100.0),
				"negating damage unleashes a dark blast",
				"negate chance %d%%" % roundi(SynergyConstants.DARKNESS_NEGATE_CHANCE_T9 * 100.0),
				"",
			]
		A.LIGHT:
			return [
				"%d%% of shots are holy (+%d%% damage)" % [roundi(SynergyConstants.LIGHT_HOLY_CHANCE * 100.0), roundi(SynergyConstants.LIGHT_HOLY_BONUS * 100.0)],
				"holy bullets may slay basic enemies (%d%%)" % roundi(SynergyConstants.LIGHT_INSTAKILL_CHANCE * 100.0),
				"holy shot chance %d%%" % roundi(SynergyConstants.LIGHT_HOLY_CHANCE_T9 * 100.0),
				"",
			]
		A.MAGIC:
			return [
				"magic beams jump between enemies",
				"beams bounce back",
				"",
				"",
			]
		A.EVIL:
			return [
				"each kill grants +%.1f%% damage until the next room" % (SynergyConstants.EVIL_RAGE_PER_KILL * 100.0),
				"rage lasts until the next floor",
				"",
				"",
			]
	return ["", "", "", ""]
