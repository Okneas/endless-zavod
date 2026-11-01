class_name ProgressionSettings
extends Resource
## Опыт и уровень персонажа. Данные: data/content/balance/progression_settings.tres
## (подключены в game_config.tres). Значения по умолчанию нейтральные: числа лежат только в .tres.
## Уровень даёт допуск к экипировке оружия (срез 5) и рост крита (07-progression-lore).

@export_range(1, 100, 1) var start_level: int = 1
@export_range(1, 100, 1) var max_level: int = 1
## Опыт до следующего уровня = xp_base * уровень в степени xp_exponent.
@export_range(1.0, 100000.0, 1.0) var xp_base: float = 1.0
@export_range(0.5, 3.0, 0.05) var xp_exponent: float = 1.0
## Прибавка к шансу крита за каждый уровень выше первого (0.002 = +0.2%).
@export_range(0.0, 0.1, 0.0005) var crit_per_level: float = 0.0
