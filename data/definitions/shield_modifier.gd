class_name ShieldModifier
extends Resource
## Модификатор щита (№93): улучшает одну характеристику на случайное число процентов из диапазона. Число модификаторов задаёт
## качество щита (как у частей оружия, QualityTier.modifier_count). Данные: data/content/shields/modifiers/*.tres.

## Какую характеристику сдвигает. DELAY улучшается уменьшением (значения в .tres отрицательные). EFFECT усиливает особенность вида
## (урон новы и шипов, шанс поглощения) и подходит только видам с особенностью.
enum Stat { CAPACITY, RATE, DELAY, EFFECT }

## Прилагательное мужского рода для названия («Ёмкий щит»).
@export var name_key: String = ""
@export var stat: Stat = Stat.CAPACITY
## Сдвиг в процентах (0.25 — плюс 25%, -0.25 — минус 25%). Случайно между min_value и max_value.
@export_range(-1.0, 5.0, 0.01) var min_value: float = 0.0
@export_range(-1.0, 5.0, 0.01) var max_value: float = 0.0
## Для каких видов подходит (пусто — для всех).
@export var kinds: Array[ShieldDefinition.Kind] = []
