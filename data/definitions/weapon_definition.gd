class_name WeaponDefinition
extends Resource
## Оружие как фиксированный набор частей, заданный данными (стартовый пистолет, 04-extraction).
## Случайные сборки делает WeaponGenerator (weapons/), готовое оружие в игре это WeaponInstance.

## Ключ названия оружия в таблице переводов (у случайного оружия название собирается из частей).
@export var name_key: String = ""
## Части оружия: нужен один корпус, остальные необязательны.
@export var parts: Array[WeaponPart] = []


## Считает итоговые характеристики: база корпуса, затем множители всех частей (без качества и уровня).
## Расчёт общий с WeaponInstance, чтобы формула была одна.
func compute_stats() -> WeaponStats:
	return WeaponInstance.from_definition(self, 1, 0, null).compute_stats()