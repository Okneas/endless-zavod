class_name WeaponInstance
extends RefCounted
## Конкретное оружие: уровень, набор выпавших частей и название (02-combat-fps). Из частей считаются
## характеристики (compute_stats), из корпуса берутся тип, качество и бренд. Не зависит от автозагрузок:
## настройки генерации (рост урона за уровень) передаются в поле settings.

const STAT_COUNT: int = 10

var level: int = 1
var parts: Array[PartInstance] = []
## Основа ключа префикса в начале названия или пустая строка.
var prefix: String = ""
## Настройки генерации: нужны для роста урона по уровню. Без них рост не применяется.
var settings: WeaponGenerationSettings
## Стартовое оружие: название берётся из шаблона целиком, уровень равен уровню персонажа (04-extraction).
var template_name_key: String = ""
var follows_player_level: bool = false
## Вечное оружие (стартовый пистолет): не теряется при смерти, его нельзя выбросить и продать (04-extraction).
var is_eternal: bool = false
## Патроны в магазине; -1 пока оружие ни разу не экипировали (магазин полный).
var ammo: int = -1


## Оружие из фиксированного набора частей (стартовый пистолет). Качество одинаково у всех частей.
static func from_definition(definition: WeaponDefinition, p_level: int, p_quality: int, p_settings: WeaponGenerationSettings) -> WeaponInstance:
	var instance: WeaponInstance = WeaponInstance.new()
	instance.level = p_level
	instance.settings = p_settings
	instance.template_name_key = definition.name_key
	for part: WeaponPart in definition.parts:
		instance.parts.append(PartInstance.create(part, p_quality))
	return instance


func get_body() -> PartInstance:
	return get_part(WeaponPart.PartType.BODY)


func get_part(part_type: WeaponPart.PartType) -> PartInstance:
	for instance: PartInstance in parts:
		if instance.part.part_type == part_type:
			return instance
	return null


## Прицел корпуса. Оптика возможна, только если у корпуса есть её данные.
func get_sight() -> CombatEnums.SightType:
	var body: PartInstance = get_body()
	if body.sight == CombatEnums.SightType.OPTIC and body.part.has_optic():
		return CombatEnums.SightType.OPTIC
	return CombatEnums.SightType.IRON


## Точка, через которую смотрит глаз при прицеливании: целик или центр оптики.
func get_aim_anchor() -> Vector3:
	var body: WeaponPart = get_body().part
	return body.optic_aim_anchor_position if get_sight() == CombatEnums.SightType.OPTIC else body.aim_anchor_position


## Тип оружия определяет корпус.
func get_weapon_type() -> CombatEnums.WeaponType:
	return get_body().part.weapon_type


## Название типа для карточки: семейство корпуса (помповый дробовик, двустволка), а если его нет, название типа.
func get_type_name() -> String:
	var family: String = get_body().part.family_key
	if family != "":
		return tr(family)
	return tr("WEAPON_TYPE_" + CombatEnums.WeaponType.keys()[get_weapon_type()])


## Качество оружия равно качеству корпуса (№29).
func get_quality() -> int:
	return get_body().quality


## Бренд оружия это производитель корпуса (№29). У стартового оружия его нет.
func get_manufacturer() -> Manufacturer:
	return get_body().part.manufacturer


## Все особенности для карточки: фирменные особенности частей и особенности аксессуара.
func get_features() -> Array[PartFeature]:
	var result: Array[PartFeature] = []
	for instance: PartInstance in parts:
		if instance.part.signature != null:
			result.append(instance.part.signature)
		for feature: PartFeature in instance.features:
			result.append(feature)
	if get_sight() == CombatEnums.SightType.OPTIC and settings != null and settings.optic_feature != null:
		result.append(settings.optic_feature)
	return result


## DPS на карточке: урон за выстрел (у дробовика сумма дробин) на темп стрельбы. Перезарядка не учитывается.
func get_dps() -> float:
	var stats: WeaponStats = compute_stats()
	return stats.damage * stats.fire_rate


## Цена по формуле из 05-shop-economy: множитель уровня на сумму цен частей с множителем качества и надбавка за модификаторы.
## Числа в WeaponGenerationSettings и QualityScale. Без настроек считается сумма базовых цен.
func get_price() -> int:
	var total: float = 0.0
	var modifier_count: int = 0
	for instance: PartInstance in parts:
		var quality_multiplier: float = 1.0
		if settings != null and settings.quality_scale != null and instance.quality < settings.quality_scale.tiers.size():
			quality_multiplier = settings.quality_scale.tiers[instance.quality].price_multiplier
		total += float(instance.part.base_price) * quality_multiplier
		modifier_count += instance.modifiers.size()
	if settings == null:
		return roundi(total)
	var level_multiplier: float = 1.0 + settings.price_per_level * float(maxi(level - 1, 0))
	return roundi(total * level_multiplier + float(modifier_count * settings.modifier_price))


## Множитель урона от уровня оружия.
func get_level_factor() -> float:
	if settings == null:
		return 1.0
	return 1.0 + settings.damage_per_level * float(maxi(level - 1, 0))


## Название: «[префикс] [слова частей] [корпус]», прилагательные по роду корпуса (№49, №70).
func get_display_name() -> String:
	if template_name_key != "":
		return tr(template_name_key)
	var body: PartInstance = get_body()
	var suffix: String = _gender_suffix(body.part.gender)
	var words: PackedStringArray = []
	if prefix != "":
		words.append(tr(prefix + suffix))
	for instance: PartInstance in parts:
		if instance.name_word != "":
			words.append(tr(instance.name_word + suffix))
	words.append(tr(body.part.name_key))
	return " ".join(words)


## Итоговые характеристики: база корпуса, затем множители всех частей, уклон производителей,
## модификаторы, особенности и рост по уровню.
func compute_stats() -> WeaponStats:
	var body: PartInstance = get_body()
	assert(body != null, "В оружии нет корпуса (WeaponPart типа BODY)")
	var base: WeaponPart = body.part
	var mult: Array[float] = []
	mult.resize(STAT_COUNT)
	mult.fill(1.0)
	var acc: Dictionary = {"crit": base.base_crit_chance, "slide": 0.0, "air": 0.0, "melee": 0.0, "element": CombatEnums.Element.NONE}
	for instance: PartInstance in parts:
		var part: WeaponPart = instance.part
		mult[CombatEnums.Stat.DAMAGE] *= part.damage_mult
		mult[CombatEnums.Stat.FIRE_RATE] *= part.fire_rate_mult
		mult[CombatEnums.Stat.MAGAZINE_SIZE] *= part.magazine_size_mult
		mult[CombatEnums.Stat.RELOAD_TIME] *= part.reload_time_mult
		mult[CombatEnums.Stat.SPREAD] *= part.spread_mult
		mult[CombatEnums.Stat.RANGE] *= part.range_mult
		mult[CombatEnums.Stat.RECOIL] *= part.recoil_mult
		mult[CombatEnums.Stat.AIM_TIME] *= part.aim_time_mult
		mult[CombatEnums.Stat.MOVEMENT_SPREAD] *= part.movement_spread_mult
		acc["crit"] += part.crit_chance_add
		# Стихия берётся у первой части или особенности, которая её задаёт.
		if acc["element"] == CombatEnums.Element.NONE and part.element != CombatEnums.Element.NONE:
			acc["element"] = part.element
		_apply_manufacturer(part, mult)
		for rolled: RolledModifier in instance.modifiers:
			_apply_stat(rolled.modifier.stat, rolled.value, mult, acc)
		if part.signature != null:
			_apply_feature(part.signature, mult, acc)
		for feature: PartFeature in instance.features:
			_apply_feature(feature, mult, acc)
	var stats: WeaponStats = WeaponStats.new()
	stats.damage = base.base_damage * mult[CombatEnums.Stat.DAMAGE] * get_level_factor()
	stats.fire_rate = base.base_fire_rate * mult[CombatEnums.Stat.FIRE_RATE]
	stats.automatic = base.automatic
	stats.magazine_size = maxi(1, roundi(float(base.base_magazine_size) * mult[CombatEnums.Stat.MAGAZINE_SIZE]))
	stats.reload_time = base.base_reload_time * mult[CombatEnums.Stat.RELOAD_TIME]
	stats.spread_deg = base.base_spread_deg * mult[CombatEnums.Stat.SPREAD]
	stats.weapon_range = base.base_range * mult[CombatEnums.Stat.RANGE]
	stats.recoil_deg = base.base_recoil_deg * mult[CombatEnums.Stat.RECOIL]
	stats.aim_time = base.base_aim_time * mult[CombatEnums.Stat.AIM_TIME]
	stats.aim_zoom = base.optic_aim_zoom if get_sight() == CombatEnums.SightType.OPTIC else base.aim_zoom
	stats.crit_chance = acc["crit"]
	stats.weapon_type = base.weapon_type
	stats.element = acc["element"]
	stats.pellets = base.base_pellets
	stats.movement_spread_mult = mult[CombatEnums.Stat.MOVEMENT_SPREAD]
	stats.slide_damage_bonus = acc["slide"]
	stats.air_damage_bonus = acc["air"]
	stats.melee_damage_bonus = acc["melee"]
	return stats


## Короткие строки для отладочной надписи: по одной на часть.
func describe_parts() -> PackedStringArray:
	var lines: PackedStringArray = []
	var scale: QualityScale = settings.quality_scale if settings != null else null
	for instance: PartInstance in parts:
		var part: WeaponPart = instance.part
		var maker: String = tr(part.manufacturer.name_key) if part.manufacturer != null else "-"
		var quality: String = tr(scale.tiers[instance.quality].name_key) if scale != null and instance.quality < scale.tiers.size() else str(instance.quality)
		var extras: PackedStringArray = []
		if part.part_type == WeaponPart.PartType.BODY and get_sight() == CombatEnums.SightType.OPTIC and settings != null and settings.optic_feature != null:
			extras.append(tr(settings.optic_feature.name_key))
		if not instance.modifiers.is_empty():
			extras.append("+%d мод." % instance.modifiers.size())
		for feature: PartFeature in instance.features:
			extras.append(tr(feature.name_key))
		if part.signature != null:
			extras.append(tr(part.signature.name_key))
		lines.append("%s: %s, %s, %s%s" % [tr("PART_TYPE_" + WeaponPart.PartType.keys()[part.part_type]), tr(part.name_key), maker, quality, (" (" + ", ".join(extras) + ")") if not extras.is_empty() else ""])
	return lines


func _apply_manufacturer(part: WeaponPart, mult: Array[float]) -> void:
	var maker: Manufacturer = part.manufacturer
	if maker == null:
		return
	# Уклон применяет только часть, которой принадлежит характеристика (смешение производителей не удваивает его).
	match part.part_type:
		WeaponPart.PartType.BODY:
			mult[CombatEnums.Stat.DAMAGE] *= maker.damage_mult
			mult[CombatEnums.Stat.FIRE_RATE] *= maker.fire_rate_mult
		WeaponPart.PartType.BARREL:
			mult[CombatEnums.Stat.SPREAD] *= maker.spread_mult
			mult[CombatEnums.Stat.RANGE] *= maker.range_mult
		WeaponPart.PartType.GRIP:
			mult[CombatEnums.Stat.RECOIL] *= maker.recoil_mult
			mult[CombatEnums.Stat.AIM_TIME] *= maker.aim_time_mult
		WeaponPart.PartType.MAGAZINE:
			mult[CombatEnums.Stat.MAGAZINE_SIZE] *= maker.magazine_size_mult
			mult[CombatEnums.Stat.RELOAD_TIME] *= maker.reload_time_mult
		WeaponPart.PartType.STOCK:
			mult[CombatEnums.Stat.MOVEMENT_SPREAD] *= maker.movement_spread_mult


func _apply_stat(stat: CombatEnums.Stat, value: float, mult: Array[float], acc: Dictionary) -> void:
	if stat == CombatEnums.Stat.CRIT_CHANCE:
		acc["crit"] += value
	else:
		mult[stat] *= PartModifier.factor_for(stat, value)


func _apply_feature(feature: PartFeature, mult: Array[float], acc: Dictionary) -> void:
	for change: PartModifier in feature.stat_changes:
		_apply_stat(change.stat, (change.min_value + change.max_value) * 0.5, mult, acc)
	match feature.kind:
		CombatEnums.FeatureKind.ELEMENT:
			if acc["element"] == CombatEnums.Element.NONE:
				acc["element"] = feature.element
		CombatEnums.FeatureKind.SLIDE_DAMAGE:
			acc["slide"] += feature.value
		CombatEnums.FeatureKind.AIR_DAMAGE:
			acc["air"] += feature.value
		CombatEnums.FeatureKind.MELEE_DAMAGE:
			acc["melee"] += feature.value


func _gender_suffix(gender: CombatEnums.Gender) -> String:
	match gender:
		CombatEnums.Gender.FEMININE:
			return "_F"
		CombatEnums.Gender.NEUTER:
			return "_N"
	return "_M"