class_name GrenadeModifier
extends Resource
## Модификатор гранаты (№92): улучшает одну характеристику на случайное число процентов из диапазона. Число модификаторов задаёт качество
## гранаты (как у частей оружия, QualityTier.modifier_count), повторов по характеристике нет. Данные: data/content/grenades/modifiers/*.tres.

## Какую характеристику сдвигает. COOLDOWN и FUSE улучшаются уменьшением (значения в .tres отрицательные), BOMBLETS и PULL только для своих типов.
enum Stat { DAMAGE, RADIUS, COOLDOWN, FUSE, BOMBLETS, PULL }

## Прилагательное женского рода для названия («Мощная осколочная граната»).
@export var name_key: String = ""
@export var stat: Stat = Stat.DAMAGE
## Сдвиг в процентах (0.25 — плюс 25%, -0.25 — минус 25%), для BOMBLETS в штуках. Случайно между min_value и max_value.
@export_range(-1.0, 5.0, 0.01) var min_value: float = 0.0
@export_range(-1.0, 5.0, 0.01) var max_value: float = 0.0
## Для каких видов подходит (пусто — для всех).
@export var kinds: Array[GrenadeDefinition.Kind] = []
