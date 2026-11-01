class_name RoomDefinition
extends Resource
## Запись пула комнат отдела (№41): сцена комнаты или перехода (коридора), тип, вес и допустимые зоны. Входы и габариты
## читаются из самой сцены (узлы RoomEntrance и корень RoomPiece). Новая комната это новый файл в data/content/rooms/
## без правки кода. Числа по умолчанию нейтральные.

## GATE это шлюз между зонами (№82): испытание, после которого открывается портал в следующую зону. Порядок значений
## менять нельзя (они записаны в .tres): новые типы добавляются в конец.
enum Kind { START, COMBAT, LOOT, SHOP, BOSS, EVACUATION, CORRIDOR, GATE }
## Испытание шлюза: волны врагов или элитный враг (мини-босс зоны).
enum GateMode { WAVES, ELITE }

## Сцена комнаты (корень со скриптом RoomPiece).
@export var scene: PackedScene
@export var kind: Kind = Kind.COMBAT
## Только для шлюза: какое испытание в этой комнате (число волн и элитный враг настраиваются в run_settings.tres).
@export var gate_mode: GateMode = GateMode.WAVES
## Вес при выборе среди вариантов того же типа (больше вес, чаще выпадает).
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
## Самая ранняя зона, в которой комната может выпасть.
@export_range(1, 99, 1) var min_zone: int = 1
## Самая поздняя зона (0 без ограничения).
@export_range(0, 99, 1) var max_zone: int = 0
## Во сколько раз врагов в этой комнате больше или меньше, чем даёт формула зоны (большим комнатам нужно больше врагов).
@export_range(0.1, 5.0, 0.05) var enemy_scale: float = 1.0


func is_allowed_on(zone_number: int) -> bool:
	return zone_number >= min_zone and (max_zone == 0 or zone_number <= max_zone)
