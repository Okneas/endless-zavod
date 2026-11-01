class_name GrenadeInstance
extends RefCounted
## Граната игрока (№92, №33): тип (GrenadeDefinition), качество, уровень и модификаторы. Не составная. Итоговые числа считает compute_stats().
## Перезарядка после броска своя у каждой гранаты (cooldown_left, секунды), идёт, пока граната в слоте. Без автозагрузок: настройки передаются.

## Случайно выпавший модификатор: что и на сколько.
class Rolled extends RefCounted:
	var modifier: GrenadeModifier
	var value: float


## Итоговые характеристики с модификаторами и уровнем.
class Stats extends RefCounted:
	var damage: float = 0.0
	var radius: float = 0.0
	var cooldown: float = 0.0
	var fuse: float = 0.0
	var bomblets: int = 0
	var pull_time: float = 0.0


var definition: GrenadeDefinition
var settings: GrenadeSettings
var quality_scale: QualityScale
var quality: int = 0
var level: int = 1
var modifiers: Array[Rolled] = []
## Вечная (стартовая) не теряется при смерти и не продаётся, растёт вместе с уровнем персонажа.
var is_eternal: bool = false
## Сколько секунд ждать до следующего броска.
var cooldown_left: float = 0.0


## Название: «[прилагательное первого модификатора] [тип]»: «Мощная осколочная граната».
func get_display_name() -> String:
	if modifiers.is_empty():
		return TranslationServer.translate(definition.name_key)
	return "%s %s" % [TranslationServer.translate(modifiers[0].modifier.name_key), TranslationServer.translate(definition.name_lower_key)]


func get_quality_name() -> String:
	return TranslationServer.translate(quality_scale.tiers[quality].name_key) if quality_scale != null and quality < quality_scale.tiers.size() else ""


func get_quality_color() -> Color:
	return quality_scale.tiers[quality].color if quality_scale != null and quality < quality_scale.tiers.size() else definition.color


## Итоговые характеристики: база типа, рост урона по уровню, модификаторы.
func compute_stats() -> Stats:
	var stats: Stats = Stats.new()
	var level_factor: float = 1.0 + (settings.damage_per_level if settings != null else 0.0) * float(maxi(level - 1, 0))
	var damage_mult: float = 1.0
	var radius_mult: float = 1.0
	var cooldown_mult: float = 1.0
	var fuse_mult: float = 1.0
	var pull_mult: float = 1.0
	var extra_bomblets: int = 0
	for rolled: Rolled in modifiers:
		match rolled.modifier.stat:
			GrenadeModifier.Stat.DAMAGE:
				damage_mult += rolled.value
			GrenadeModifier.Stat.RADIUS:
				radius_mult += rolled.value
			GrenadeModifier.Stat.COOLDOWN:
				cooldown_mult += rolled.value
			GrenadeModifier.Stat.FUSE:
				fuse_mult += rolled.value
			GrenadeModifier.Stat.BOMBLETS:
				extra_bomblets += roundi(rolled.value)
			GrenadeModifier.Stat.PULL:
				pull_mult += rolled.value
	stats.damage = definition.base_damage * level_factor * maxf(damage_mult, 0.1)
	stats.radius = definition.blast_radius * maxf(radius_mult, 0.2)
	stats.cooldown = definition.cooldown * maxf(cooldown_mult, 0.1)
	stats.fuse = definition.fuse_time * maxf(fuse_mult, 0.2)
	stats.bomblets = maxi(definition.bomblets + (extra_bomblets if definition.kind == GrenadeDefinition.Kind.CLUSTER else 0), 0)
	stats.pull_time = definition.pull_time * maxf(pull_mult, 0.2)
	return stats


## Цена: база типа с множителем качества, рост по уровню и надбавка за модификаторы.
func get_price() -> int:
	var quality_multiplier: float = quality_scale.tiers[quality].price_multiplier if quality_scale != null and quality < quality_scale.tiers.size() else 1.0
	var level_multiplier: float = 1.0 + (settings.price_per_level if settings != null else 0.0) * float(maxi(level - 1, 0))
	var modifier_price: int = settings.modifier_price if settings != null else 0
	return roundi(float(definition.base_price) * quality_multiplier * level_multiplier + float(modifiers.size() * modifier_price))


## Готова ли к броску.
func is_ready() -> bool:
	return cooldown_left <= 0.0
