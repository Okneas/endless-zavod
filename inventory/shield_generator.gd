class_name ShieldGenerator
extends RefCounted
## Генератор щитов (№93): тип по весам, качество по шкале (QualityScale оружия), модификаторы по числу, которое задаёт качество,
## из пула ShieldSettings (только подходящие типу). Без автозагрузок: настройки передаются параметрами.

var settings: ShieldSettings
var quality_scale: QualityScale


func _init(p_settings: ShieldSettings, p_quality_scale: QualityScale) -> void:
	settings = p_settings
	quality_scale = p_quality_scale


## Случайный щит уровня level. definition: нужный тип (null — случайный по весам).
func generate(rng: RandomNumberGenerator, level: int, definition: ShieldDefinition = null) -> ShieldInstance:
	var instance: ShieldInstance = ShieldInstance.new()
	instance.settings = settings
	instance.quality_scale = quality_scale
	instance.level = level
	instance.definition = definition if definition != null else _pick_type(rng)
	instance.quality = quality_scale.pick_index(rng)
	var count: int = quality_scale.tiers[instance.quality].modifier_count
	var pool: Array[ShieldModifier] = []
	for modifier: ShieldModifier in settings.modifiers:
		if modifier.kinds.is_empty() or modifier.kinds.has(instance.definition.kind):
			pool.append(modifier)
	while count > 0 and not pool.is_empty():
		var picked: ShieldModifier = pool.pop_at(rng.randi() % pool.size())
		var rolled: ShieldInstance.Rolled = ShieldInstance.Rolled.new()
		rolled.modifier = picked
		rolled.value = rng.randf_range(picked.min_value, maxf(picked.min_value, picked.max_value))
		instance.modifiers.append(rolled)
		count -= 1
	return instance


## Стартовый вечный щит: серийного качества без модификаторов, растёт вместе с уровнем персонажа.
func starter(level: int) -> ShieldInstance:
	var instance: ShieldInstance = ShieldInstance.new()
	instance.settings = settings
	instance.quality_scale = quality_scale
	instance.level = level
	instance.definition = settings.starter
	instance.quality = mini(1, quality_scale.tiers.size() - 1)
	instance.is_eternal = true
	return instance


func _pick_type(rng: RandomNumberGenerator) -> ShieldDefinition:
	var total: float = 0.0
	for definition: ShieldDefinition in settings.types:
		total += definition.weight
	var pick: float = rng.randf() * total
	for definition: ShieldDefinition in settings.types:
		pick -= definition.weight
		if pick <= 0.0:
			return definition
	return settings.types[settings.types.size() - 1]
