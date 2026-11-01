class_name ZoneMath
extends RefCounted
## Формулы зоны (03-run-structure): уровень зоны, число комнат и врагов, зона комнаты эвакуации. Без состояния, чтобы
## проверять без сцены. Все числа берутся из ZoneSettings.


## Уровень зоны (№85): растёт по кривой от 1 в первой зоне до уровня мира в последней зоне отдела. Кривая степенная
## (level_curve_exponent больше 1: медленный старт, рост к концу), поэтому прирост между зонами не одинаков. Уровень мира это
## потолок: после босса он растёт, и кривая растягивается до нового потолка.
static func zone_level(settings: ZoneSettings, world_level: int, zone_number: int) -> int:
	var cap: int = maxi(world_level, 1)
	var last: int = maxi(settings.zones_in_department - 1, 1)
	var progress: float = clampf(float(zone_number - 1) / float(last), 0.0, 1.0)
	var level: float = 1.0 + float(cap - 1) * pow(progress, settings.level_curve_exponent)
	return clampi(roundi(level), 1, cap)


## Комнат в зоне без переходов, считая стартовую; растёт с номером зоны.
static func room_count(settings: ZoneSettings, zone_number: int) -> int:
	var count: int = settings.rooms_base + floori(settings.rooms_per_zone * float(zone_number - 1))
	return clampi(count, 2, settings.rooms_max)


static func loot_room_count(settings: ZoneSettings, zone_number: int) -> int:
	return settings.loot_rooms_base + floori(settings.loot_rooms_per_zone * float(zone_number - 1))


static func enemy_count(settings: ZoneSettings, zone_number: int) -> int:
	return clampi(settings.enemies_base + floori(settings.enemies_per_zone * float(zone_number - 1)), 1, settings.enemies_max)


static func has_boss(settings: ZoneSettings, zone_number: int) -> bool:
	return zone_number == settings.zones_in_department


## Комната эвакуации (№86): в каждой зоне, номер которой кратен evacuation_every (при 3 это зоны 3, 6 и 9), кроме зоны с боссом.
static func has_evacuation(settings: ZoneSettings, zone_number: int) -> bool:
	return zone_number >= 1 and zone_number % settings.evacuation_every == 0 and not has_boss(settings, zone_number)


## Между зонами стоит шлюз (волны или элитный враг), кроме последней зоны отдела: там босс (№82).
static func has_gate(settings: ZoneSettings, zone_number: int) -> bool:
	return zone_number < settings.zones_in_department


## Врагов в волне (номер волны с единицы): база, прибавка за волну и за зону, не больше предела.
static func wave_enemy_count(run: RunSettings, zone_number: int, wave: int) -> int:
	var count: int = run.wave_enemies_base + floori(run.wave_enemies_per_wave * float(wave - 1) + run.wave_enemies_per_zone * float(zone_number - 1))
	return clampi(count, 1, run.wave_enemies_max)


## Цена эвакуации: номер_зоны x стандартная_цена x модификатор (04-extraction).
static func evacuation_price(run: RunSettings, zone_number: int) -> int:
	return roundi(float(zone_number * run.evacuation_price) * run.evacuation_price_modifier)


## Эвакуационная комната этой зоны требует оплату лутом (иначе деньгами): способ случаен и повторяем по сиду забега.
static func evacuation_pays_loot(run: RunSettings, run_seed: int, zone_number: int) -> bool:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([run_seed, zone_number, "evacuation_payment"])
	return rng.randf() < run.evacuation_loot_chance


## Множитель здоровья врага от уровня зоны: сложный процент enemy_health_per_level за каждый уровень выше первого (№83).
static func enemy_health_scale(run: RunSettings, level: int) -> float:
	return pow(1.0 + run.enemy_health_per_level, float(maxi(level - 1, 0)))


static func enemy_damage_scale(run: RunSettings, level: int) -> float:
	return pow(1.0 + run.enemy_damage_per_level, float(maxi(level - 1, 0)))


## Уровень мира после победы над боссом отдела.
static func next_world_level(run: RunSettings, current: int) -> int:
	return mini(current + run.world_level_step, run.world_level_max)
