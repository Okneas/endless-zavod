class_name WeaponGenerator
extends RefCounted
## Генератор оружия (02-combat-fps, №15, №16, №28, №29, №49, №70). Каждая часть независимо выбирает
## производителя (у производителя отдела шанс выше), вариант, подходящий типу оружия, и своё качество.
## Качество оружия равно качеству корпуса. Число модификаторов части задаёт её качество, они берутся из
## пула производителя части. Аксессуар получает особенности по своему качеству. Название собирается в конце.
## Все числа и пулы в WeaponGenerationSettings, класс не зависит от автозагрузок.

## Сколько раз generate_part пробует другой тип, если для выбранного нет частей.
const PART_ATTEMPTS: int = 8

var settings: WeaponGenerationSettings
var catalog: WeaponCatalog


func _init(p_settings: WeaponGenerationSettings, p_catalog: WeaponCatalog = null) -> void:
	settings = p_settings
	catalog = p_catalog if p_catalog != null else WeaponCatalog.for_directory(p_settings.parts_directory)


## Случайное оружие. weapon_type -1 = случайный тип из настроек, department = производитель отдела.
func generate(rng: RandomNumberGenerator, level: int, weapon_type: int = -1, department: Manufacturer = null) -> WeaponInstance:
	var type: CombatEnums.WeaponType = weapon_type as CombatEnums.WeaponType
	if weapon_type < 0:
		type = settings.weapon_types[rng.randi() % settings.weapon_types.size()]
	var instance: WeaponInstance = WeaponInstance.new()
	instance.level = level
	instance.settings = settings
	var part_types: Array[WeaponPart.PartType] = [WeaponPart.PartType.BODY, WeaponPart.PartType.BARREL, WeaponPart.PartType.GRIP, WeaponPart.PartType.MAGAZINE]
	if settings.stock_types.has(type):
		part_types.append(WeaponPart.PartType.STOCK)
	if rng.randf() < settings.accessory_chance:
		part_types.append(WeaponPart.PartType.ACCESSORY)
	for part_type: WeaponPart.PartType in part_types:
		var rolled: PartInstance = _roll_part(rng, part_type, type, department)
		if rolled == null:
			push_warning("В каталоге нет части %s для типа оружия %s" % [WeaponPart.PartType.keys()[part_type], CombatEnums.WeaponType.keys()[type]])
			if part_type == WeaponPart.PartType.BODY:
				return null
			continue
		instance.parts.append(rolled)
	_roll_name(rng, instance)
	return instance


## Случайная деталь оружия отдельным предметом (срез 7б, №83): тип оружия и тип детали случайны, производитель, качество,
## модификаторы и особенности аксессуара как у частей целого оружия. Возвращает null, если в каталоге ничего подходящего нет.
func generate_part(rng: RandomNumberGenerator, department: Manufacturer = null) -> PartInstance:
	for attempt: int in PART_ATTEMPTS:
		var type: CombatEnums.WeaponType = settings.weapon_types[rng.randi() % settings.weapon_types.size()]
		var part_types: Array[WeaponPart.PartType] = [WeaponPart.PartType.BODY, WeaponPart.PartType.BARREL, WeaponPart.PartType.GRIP, WeaponPart.PartType.MAGAZINE, WeaponPart.PartType.ACCESSORY]
		if settings.stock_types.has(type):
			part_types.append(WeaponPart.PartType.STOCK)
		var rolled: PartInstance = _roll_part(rng, part_types[rng.randi() % part_types.size()], type, department)
		if rolled != null:
			return rolled
	return null


func _roll_part(rng: RandomNumberGenerator, part_type: WeaponPart.PartType, type: CombatEnums.WeaponType, department: Manufacturer) -> PartInstance:
	var maker: Manufacturer = _pick_manufacturer(rng, part_type, type, department)
	if maker == null:
		return null
	var variants: Array[WeaponPart] = catalog.get_variants(part_type, maker, type)
	var part: WeaponPart = variants[rng.randi() % variants.size()]
	var rolled: PartInstance = PartInstance.create(part, settings.quality_scale.pick_index(rng))
	var tier: QualityTier = settings.quality_scale.tiers[rolled.quality]
	_roll_modifiers(rng, rolled, maker, tier.modifier_count)
	if part_type == WeaponPart.PartType.BODY and part.has_optic():
		# Прицел свойство корпуса: оптика выпадает с общим шансом у любого производителя, у «своих» выше.
		var optic_chance: float = clampf(settings.optic_chance + maker.optic_chance_bonus, 0.0, 1.0)
		rolled.sight = CombatEnums.SightType.OPTIC if rng.randf() < optic_chance else CombatEnums.SightType.IRON
	if part_type == WeaponPart.PartType.ACCESSORY:
		rolled.features = _roll_features(rng, maker, tier.accessory_feature_count)
	return rolled


# Производитель каждой части выбирается независимо; производитель отдела с заданным шансом (№15).
func _pick_manufacturer(rng: RandomNumberGenerator, part_type: WeaponPart.PartType, type: CombatEnums.WeaponType, department: Manufacturer) -> Manufacturer:
	var candidates: Array[Manufacturer] = []
	for maker: Manufacturer in settings.manufacturers:
		if not catalog.get_variants(part_type, maker, type).is_empty():
			candidates.append(maker)
	if candidates.is_empty():
		return null
	if department != null and candidates.has(department) and rng.randf() < settings.department_manufacturer_chance:
		return department
	return candidates[rng.randi() % candidates.size()]


func _roll_modifiers(rng: RandomNumberGenerator, rolled: PartInstance, maker: Manufacturer, count: int) -> void:
	var pool: Array[PartModifier] = []
	pool.assign(maker.modifier_pool)
	for i: int in mini(count, pool.size()):
		var index: int = rng.randi() % pool.size()
		var modifier: PartModifier = pool[index]
		pool.remove_at(index)
		var value: float = snappedf(rng.randf_range(modifier.min_value, modifier.max_value), 0.001)
		rolled.modifiers.append(RolledModifier.create(modifier, value))


# Особенности аксессуара: разные между собой, не больше одной стихии, предпочтения производителя весят больше.
func _roll_features(rng: RandomNumberGenerator, maker: Manufacturer, count: int) -> Array[PartFeature]:
	var pool: Array[PartFeature] = []
	pool.assign(settings.accessory_features)
	var result: Array[PartFeature] = []
	for i: int in count:
		if pool.is_empty():
			break
		var total: float = 0.0
		for feature: PartFeature in pool:
			total += _feature_weight(feature, maker)
		var roll: float = rng.randf() * total
		var chosen: PartFeature = pool[pool.size() - 1]
		for feature: PartFeature in pool:
			roll -= _feature_weight(feature, maker)
			if roll <= 0.0:
				chosen = feature
				break
		result.append(chosen)
		pool.erase(chosen)
		if chosen.kind == CombatEnums.FeatureKind.ELEMENT:
			for other: PartFeature in pool.duplicate():
				if other.kind == CombatEnums.FeatureKind.ELEMENT:
					pool.erase(other)
	return result


func _feature_weight(feature: PartFeature, maker: Manufacturer) -> float:
	return settings.preferred_feature_weight if maker.preferred_features.has(feature) else 1.0


# Название (№49): префикс из общего пула и слова от частей (у каждой свой пул и шанс), порядок фиксирован.
func _roll_name(rng: RandomNumberGenerator, instance: WeaponInstance) -> void:
	if not settings.prefix_keys.is_empty() and rng.randf() < settings.prefix_chance:
		instance.prefix = settings.prefix_keys[rng.randi() % settings.prefix_keys.size()]
	var words_left: int = settings.max_part_words
	for part_type: WeaponPart.PartType in [WeaponPart.PartType.BARREL, WeaponPart.PartType.GRIP, WeaponPart.PartType.MAGAZINE, WeaponPart.PartType.STOCK, WeaponPart.PartType.ACCESSORY]:
		var part_instance: PartInstance = instance.get_part(part_type)
		if part_instance == null or part_instance.part.name_words.is_empty() or words_left <= 0:
			continue
		if rng.randf() < settings.part_word_chance:
			part_instance.name_word = part_instance.part.name_words[rng.randi() % part_instance.part.name_words.size()]
			words_left -= 1