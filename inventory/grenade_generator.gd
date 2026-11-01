class_name GrenadeGenerator
extends RefCounted
## Генератор гранат (№92): тип по весам, качество по шкале (QualityScale оружия), модификаторы по числу, которое задаёт качество, из
## пула GrenadeSettings (по одному на характеристику, только подходящие типу). Без автозагрузок: настройки передаются параметрами.

var settings: GrenadeSettings
var quality_scale: QualityScale


func _init(p_settings: GrenadeSettings, p_quality_scale: QualityScale) -> void:
	settings = p_settings
	quality_scale = p_quality_scale


## Случайная граната уровня level. definition: нужный тип (null — случайный по весам).
func generate(rng: RandomNumberGenerator, level: int, definition: GrenadeDefinition = null) -> GrenadeInstance:
	var instance: GrenadeInstance = GrenadeInstance.new()
	instance.settings = settings
	instance.quality_scale = quality_scale
	instance.level = level
	instance.definition = definition if definition != null else _pick_type(rng)
	instance.quality = quality_scale.pick_index(rng)
	var count: int = quality_scale.tiers[instance.quality].modifier_count
	var pool: Array[GrenadeModifier] = []
	for modifier: GrenadeModifier in settings.modifiers:
		if modifier.kinds.is_empty() or modifier.kinds.has(instance.definition.kind):
			pool.append(modifier)
	while count > 0 and not pool.is_empty():
		var picked: GrenadeModifier = pool.pop_at(rng.randi() % pool.size())
		var rolled: GrenadeInstance.Rolled = GrenadeInstance.Rolled.new()
		rolled.modifier = picked
		rolled.value = rng.randf_range(picked.min_value, maxf(picked.min_value, picked.max_value))
		if picked.stat == GrenadeModifier.Stat.BOMBLETS:
			rolled.value = float(maxi(roundi(rolled.value), 1))
		instance.modifiers.append(rolled)
		count -= 1
	return instance


## Стартовая вечная граната: осколочная серийного качества без модификаторов, растёт вместе с уровнем персонажа.
func starter(level: int) -> GrenadeInstance:
	var instance: GrenadeInstance = GrenadeInstance.new()
	instance.settings = settings
	instance.quality_scale = quality_scale
	instance.level = level
	instance.definition = settings.starter
	instance.quality = mini(1, quality_scale.tiers.size() - 1)
	instance.is_eternal = true
	return instance


func _pick_type(rng: RandomNumberGenerator) -> GrenadeDefinition:
	var total: float = 0.0
	for definition: GrenadeDefinition in settings.types:
		total += definition.weight
	var pick: float = rng.randf() * total
	for definition: GrenadeDefinition in settings.types:
		pick -= definition.weight
		if pick <= 0.0:
			return definition
	return settings.types[settings.types.size() - 1]
