class_name EnemyModifierSettings
extends Resource
## Модификаторы врагов (№92): у какого врага и с каким шансом бывает префикс. Решение автора: один префикс на врага, шанс растёт с зоной,
## у элитных врагов и боссов префиксов нет (EnemySettings.allows_modifier). Данные: data/content/balance/enemy_modifier_settings.tres
## (слот enemy_modifiers в game_config.tres). Значения по умолчанию нейтральные: числа лежат только в .tres.

@export var enabled: bool = false
@export var modifiers: Array[EnemyModifier] = []
## Шанс префикса у врага: база плюс прибавка за каждую зону выше первой, не больше предела.
@export_range(0.0, 1.0, 0.01) var chance_base: float = 0.0
@export_range(0.0, 1.0, 0.005) var chance_per_zone: float = 0.0
@export_range(0.0, 1.0, 0.01) var chance_max: float = 0.0


## Шанс префикса в зоне zone.
func chance_for_zone(zone: int) -> float:
	return clampf(chance_base + chance_per_zone * float(maxi(zone - 1, 0)), 0.0, chance_max)


## Бросок: модификатор для врага в зоне zone или null. Учитывает шанс зоны, вес и самую раннюю зону каждого префикса.
func roll(rng: RandomNumberGenerator, zone: int) -> EnemyModifier:
	if not enabled or rng.randf() >= chance_for_zone(zone):
		return null
	var pool: Array[EnemyModifier] = []
	var total: float = 0.0
	for modifier: EnemyModifier in modifiers:
		if modifier.min_zone <= zone:
			pool.append(modifier)
			total += modifier.weight
	if pool.is_empty():
		return null
	var pick: float = rng.randf() * total
	for modifier: EnemyModifier in pool:
		pick -= modifier.weight
		if pick <= 0.0:
			return modifier
	return pool[pool.size() - 1]
