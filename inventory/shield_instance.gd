class_name ShieldInstance
extends RefCounted
## Щит игрока (№93): тип (ShieldDefinition), качество, уровень и модификаторы. Не составной. Итоговые числа считает compute_stats().
## Без автозагрузок: настройки передаются.

## Случайно выпавший модификатор: что и на сколько.
class Rolled extends RefCounted:
	var modifier: ShieldModifier
	var value: float


## Итоговые характеристики с модификаторами и уровнем.
class Stats extends RefCounted:
	var capacity: float = 0.0
	var recharge_delay: float = 0.0
	var recharge_rate: float = 0.0
	## NOVA и SPIKE: урон врагам. ABSORB: шанс поглощения (0..1). У прочих 0.
	var effect_power: float = 0.0
	var effect_radius: float = 0.0
	var effect_cooldown: float = 0.0
	var effect_restore: float = 0.0


var definition: ShieldDefinition
var settings: ShieldSettings
var quality_scale: QualityScale
var quality: int = 0
var level: int = 1
var modifiers: Array[Rolled] = []
## Вечный (стартовый) щит не теряется при смерти и не продаётся, растёт вместе с уровнем персонажа.
var is_eternal: bool = false


## Название: «[прилагательное первого модификатора] [тип]»: «Ёмкий тяжёлый щит».
func get_display_name() -> String:
	if modifiers.is_empty():
		return TranslationServer.translate(definition.name_key)
	return "%s %s" % [TranslationServer.translate(modifiers[0].modifier.name_key), TranslationServer.translate(definition.name_lower_key)]


func get_quality_name() -> String:
	return TranslationServer.translate(quality_scale.tiers[quality].name_key) if quality_scale != null and quality < quality_scale.tiers.size() else ""


func get_quality_color() -> Color:
	return quality_scale.tiers[quality].color if quality_scale != null and quality < quality_scale.tiers.size() else definition.color


## Итоговые характеристики: база типа, рост по уровню, модификаторы.
func compute_stats() -> Stats:
	var stats: Stats = Stats.new()
	var level_factor: float = 1.0 + (settings.capacity_per_level if settings != null else 0.0) * float(maxi(level - 1, 0))
	var capacity_mult: float = 1.0
	var rate_mult: float = 1.0
	var delay_mult: float = 1.0
	var effect_mult: float = 1.0
	for rolled: Rolled in modifiers:
		match rolled.modifier.stat:
			ShieldModifier.Stat.CAPACITY:
				capacity_mult += rolled.value
			ShieldModifier.Stat.RATE:
				rate_mult += rolled.value
			ShieldModifier.Stat.DELAY:
				delay_mult += rolled.value
			ShieldModifier.Stat.EFFECT:
				effect_mult += rolled.value
	stats.capacity = definition.base_capacity * level_factor * maxf(capacity_mult, 0.1)
	stats.recharge_rate = definition.recharge_rate * maxf(rate_mult, 0.1)
	stats.recharge_delay = definition.recharge_delay * maxf(delay_mult, 0.1)
	stats.effect_radius = definition.effect_radius
	stats.effect_cooldown = definition.effect_cooldown
	stats.effect_restore = definition.effect_restore
	match definition.kind:
		ShieldDefinition.Kind.NOVA, ShieldDefinition.Kind.SPIKE:
			stats.effect_power = definition.effect_damage * level_factor * maxf(effect_mult, 0.1)
		ShieldDefinition.Kind.ABSORB:
			var cap: float = settings.absorb_chance_cap if settings != null else 1.0
			stats.effect_power = clampf(definition.effect_chance * maxf(effect_mult, 0.0), 0.0, cap)
	return stats


## Цена: база типа с множителем качества, рост по уровню и надбавка за модификаторы.
func get_price() -> int:
	var quality_multiplier: float = quality_scale.tiers[quality].price_multiplier if quality_scale != null and quality < quality_scale.tiers.size() else 1.0
	var level_multiplier: float = 1.0 + (settings.price_per_level if settings != null else 0.0) * float(maxi(level - 1, 0))
	var modifier_price: int = settings.modifier_price if settings != null else 0
	return roundi(float(definition.base_price) * quality_multiplier * level_multiplier + float(modifiers.size() * modifier_price))
