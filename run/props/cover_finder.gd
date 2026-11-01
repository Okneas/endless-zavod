class_name CoverFinder
extends RefCounted
## Поиск укрытия для врага (№93, основа механики): среди укрытий мира (группа cover) выбирается ближайшее к врагу место, где он
## целиком скрыт от угрозы (игрока). Скрытость проверяется лучами по высотам тела: все они должны упереться в мир. Занятость мест
## ведёт CoverObject. Пока этим никто не пользуется в бою: это точка входа для будущего поведения стрелков.

const WORLD_MASK: int = 1
## Высоты тела врага над землёй, которые должны быть закрыты от глаз угрозы.
const BODY_HEIGHTS: Array[float] = [0.4, 1.0, 1.6]
## Высота глаз угрозы над землёй (глаза игрока).
const DEFAULT_EYE_HEIGHT: float = 1.65


## Ближайшее к from место за укрытием, скрытое от угрозы в точке threat, не дальше max_distance. claimer: кто ищет (его собственное
## место не считается занятым). null, если подходящего нет.
static func find_best(tree: SceneTree, from: Vector3, threat: Vector3, claimer: Object, max_distance: float, eye_height: float = DEFAULT_EYE_HEIGHT) -> CoverSpot:
	var space: PhysicsDirectSpaceState3D = tree.root.get_world_3d().direct_space_state
	var best: CoverSpot = null
	var best_distance: float = INF
	for node: Node in tree.get_nodes_in_group(&"cover"):
		var cover: CoverObject = node as CoverObject
		if cover == null or not cover.is_inside_tree():
			continue
		var slot: int = cover.get_free_slot(claimer)
		if slot < 0:
			continue
		var spot: CoverSpot = cover.get_spot(threat, slot)
		var distance: float = from.distance_to(spot.hide_position)
		if distance > max_distance or distance >= best_distance:
			continue
		if not is_hidden(space, threat, eye_height, spot.hide_position):
			continue
		best = spot
		best_distance = distance
	return best


## Занять найденное место за claimer (освобождая прежнее).
static func claim(spot: CoverSpot, claimer: Object) -> bool:
	return spot != null and spot.cover.claim(spot.slot, claimer)


## Скрыт ли враг, стоящий в position (на земле), от глаз угрозы: каждый луч к телу упирается в мир.
static func is_hidden(space: PhysicsDirectSpaceState3D, threat: Vector3, eye_height: float, position: Vector3) -> bool:
	var eye: Vector3 = threat + Vector3.UP * eye_height
	for height: float in BODY_HEIGHTS:
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(eye, position + Vector3.UP * height, WORLD_MASK)).is_empty():
			return false
	return true


## Видит ли глаз угрозы точку position (на уровне груди): с боковых точек выглядывания она должна видеть цель.
static func can_see(space: PhysicsDirectSpaceState3D, threat: Vector3, eye_height: float, position: Vector3) -> bool:
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(threat + Vector3.UP * eye_height, position + Vector3.UP * BODY_HEIGHTS[1], WORLD_MASK)).is_empty()
