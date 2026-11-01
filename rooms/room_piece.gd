class_name RoomPiece
extends Node3D
## Корень сцены комнаты или перехода (№41). Хранит габариты для проверки пересечений и умеет перечислить свои входы и
## маркеры (стартовая точка игрока, точки появления врагов, точки награды). Маркеры находятся по группам
## player_spawn, enemy_spawn, loot_spawn. Если габариты не заданы, берутся по ячейкам первой GridMap.

## Габариты в координатах комнаты: центр и размер, м. Нулевой размер значит «посчитать по GridMap».
@export var bounds_center: Vector3 = Vector3.ZERO
@export var bounds_size: Vector3 = Vector3.ZERO


## Толщина плит пола и потолка у комнат на GridMap (одна ячейка набора, 2 м) и допуски при проверке «игрок внутри».
const FLOOR_SLAB: float = 2.0
const CEILING_SLAB: float = 2.0
const ACTOR_FLOOR_TOLERANCE: float = 0.3
const ACTOR_CEILING_TOLERANCE: float = 0.15


func get_bounds() -> AABB:
	if bounds_size != Vector3.ZERO:
		return AABB(bounds_center - bounds_size * 0.5, bounds_size)
	for child: Node in find_children("*", "GridMap", true, false):
		var grid: GridMap = child as GridMap
		var cells: Array[Vector3i] = grid.get_used_cells()
		if cells.is_empty():
			continue
		var low: Vector3i = cells[0]
		var high: Vector3i = cells[0]
		for cell: Vector3i in cells:
			low = low.min(cell)
			high = high.max(cell)
		var origin: Vector3 = Vector3(low) * grid.cell_size
		var extent: Vector3 = Vector3(high - low + Vector3i.ONE) * grid.cell_size
		return AABB(grid.transform * origin, extent)
	return AABB()


## Внутренний объём комнаты для срабатывания боя (№87), в локальных координатах: от стен на 3 м, от верха пола (не от низа плиты
## пола) до низа потолка (не до верха плиты потолка). Плиты пола и потолка с проёмами стыков в него не входят.
func get_trigger_box() -> AABB:
	var bounds: AABB = get_bounds()
	var floor_top: float = bounds.position.y + FLOOR_SLAB
	var ceiling_bottom: float = bounds.end.y - CEILING_SLAB
	return AABB(Vector3(bounds.position.x + 3.0, floor_top, bounds.position.z + 3.0), Vector3(bounds.size.x - 6.0, ceiling_bottom - floor_top, bounds.size.z - 6.0))


## Стоит ли существо ногами в world_feet целиком внутри комнаты: ступни не ниже верха пола и голова не выше низа потолка, а по
## горизонтали внутри зоны срабатывания. Игрок на лестнице стыка, в проёме пола или потолка, внутри не считается: пока он там,
## бой не начинается и плита проёма не закрывается у него перед носом.
func is_actor_inside(world_feet: Vector3, height: float) -> bool:
	var local: Vector3 = to_local(world_feet)
	var box: AABB = get_trigger_box()
	return local.x >= box.position.x and local.x <= box.end.x and local.z >= box.position.z and local.z <= box.end.z \
			and local.y >= box.position.y - ACTOR_FLOOR_TOLERANCE and local.y + height <= box.end.y + ACTOR_CEILING_TOLERANCE


func get_entrances() -> Array[RoomEntrance]:
	var result: Array[RoomEntrance] = []
	for child: Node in find_children("*", "RoomEntrance", true, false):
		result.append(child as RoomEntrance)
	return result


## Маркеры группы (player_spawn, enemy_spawn, loot_spawn) внутри этой комнаты.
func get_markers(group: StringName) -> Array[Marker3D]:
	var result: Array[Marker3D] = []
	for child: Node in find_children("*", "Marker3D", true, false):
		if child.is_in_group(group):
			result.append(child as Marker3D)
	return result
