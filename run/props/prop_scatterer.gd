class_name PropScatterer
extends RefCounted
## Расстановка бочек и ящиков по комнате (№91): случайные точки внутри комнаты, на плоском месте (пол, плита), свободные от
## стен и других предметов, не у проёмов и не у места старта игрока. Число и виды из PropSettings. Работает по уже построенной
## зоне (физика комнат должна быть в мире), поэтому вызывается после ожидания навигации.

const WORLD_MASK: int = 1
const BLOCK_MASK: int = 5
## Опора должна быть плоской: нормаль почти вертикальна, четыре пробы вокруг на одной высоте.
const FLAT_NORMAL: float = 0.97
const FLAT_TOLERANCE: float = 0.08
const PROBE_OFFSET: float = 0.5
const FOOTPRINT_RADIUS: float = 0.75
const FOOTPRINT_HEIGHT: float = 1.4
const ATTEMPTS_PER_PROP: int = 16


## Расставляет в комнате бочки и ящики. is_loot: кладовая (своё число). Возвращает {"barrels": n, "crates": n} по факту.
static func scatter(room: RoomPiece, is_loot: bool, settings: PropSettings, damage_scale: float, seed_value: int, parent: Node, zone_level: int = 1) -> Dictionary:
	var result: Dictionary = {"barrels": 0, "crates": 0}
	if not settings.enabled or parent == null or not room.is_inside_tree():
		return result
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var barrels_wanted: int = _count(rng, settings.loot_barrels_min if is_loot else settings.combat_barrels_min, settings.loot_barrels_max if is_loot else settings.combat_barrels_max)
	var crates_wanted: int = _count(rng, settings.loot_crates_min if is_loot else settings.combat_crates_min, settings.loot_crates_max if is_loot else settings.combat_crates_max)
	var avoid: Array[Vector3] = []
	for entrance: RoomEntrance in room.get_entrances():
		avoid.append(entrance.global_position)
	for marker: Marker3D in room.get_markers(&"player_spawn"):
		avoid.append(marker.global_position)
	var taken: Array[Vector3] = []
	var space: PhysicsDirectSpaceState3D = room.get_world_3d().direct_space_state
	for i: int in barrels_wanted:
		if settings.barrels.is_empty():
			break
		var spot: Variant = _find_spot(room, rng, avoid, taken, settings, space)
		if spot == null:
			continue
		var definition: BarrelDefinition = _pick_barrel(rng, settings)
		var barrel: ExplosiveBarrel = ExplosiveBarrel.create(definition, settings, damage_scale)
		parent.add_child(barrel)
		barrel.global_position = (spot as Vector3) + Vector3(0.0, ExplosiveBarrel.HEIGHT * 0.5 + 0.03, 0.0)
		barrel.rotation.y = rng.randf() * TAU
		taken.append(spot as Vector3)
		result["barrels"] += 1
	for i: int in crates_wanted:
		if settings.crates.is_empty():
			break
		var spot: Variant = _find_spot(room, rng, avoid, taken, settings, space)
		if spot == null:
			continue
		var definition: CrateDefinition = _pick_crate(rng, settings)
		var crate: BreakableCrate = BreakableCrate.create(definition, settings, rng.randi())
		crate.zone_level = zone_level
		parent.add_child(crate)
		crate.global_position = (spot as Vector3) + Vector3(0.0, 0.02, 0.0)
		crate.rotation.y = rng.randf() * TAU
		taken.append(spot as Vector3)
		result["crates"] += 1
	return result


## Расставляет в боевой комнате укрытия для врагов (№93). В кладовых и прочих комнатах их нет. Укрытие не ближе cover_walk_margin
## к стенам и другим телам (вокруг можно пройти), не у проёмов и не у мест появления врагов. Возвращает число поставленных.
static func scatter_cover(room: RoomPiece, settings: PropSettings, seed_value: int, parent: Node) -> int:
	if not settings.enabled or settings.cover.is_empty() or parent == null or not room.is_inside_tree():
		return 0
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	var wanted: int = _count(rng, settings.combat_cover_min, settings.combat_cover_max)
	var avoid: Array[Vector3] = []
	for entrance: RoomEntrance in room.get_entrances():
		avoid.append(entrance.global_position)
	for marker: Marker3D in room.get_markers(&"player_spawn"):
		avoid.append(marker.global_position)
	var spawns: Array[Vector3] = []
	for marker: Marker3D in room.get_markers(&"enemy_spawn"):
		spawns.append(marker.global_position)
	var taken: Array[Vector3] = []
	var space: PhysicsDirectSpaceState3D = room.get_world_3d().direct_space_state
	var placed: int = 0
	for i: int in wanted:
		var definition: CoverDefinition = _pick_cover(rng, settings)
		var yaw: float = rng.randf() * TAU
		var spot: Variant = _find_cover_spot(room, rng, avoid, spawns, taken, settings, space, definition, yaw)
		if spot == null:
			continue
		var cover: CoverObject = CoverObject.create(definition, settings)
		parent.add_child(cover)
		cover.global_position = (spot as Vector3) + Vector3(0.0, 0.02, 0.0)
		cover.rotation.y = yaw
		taken.append(spot as Vector3)
		placed += 1
	return placed


static func _count(rng: RandomNumberGenerator, low: int, high: int) -> int:
	return rng.randi_range(low, maxi(low, high))


# Свободная плоская точка в комнате или null, если за ATTEMPTS_PER_PROP попыток не нашлось.
static func _find_spot(room: RoomPiece, rng: RandomNumberGenerator, avoid: Array[Vector3], taken: Array[Vector3], settings: PropSettings, space: PhysicsDirectSpaceState3D) -> Variant:
	var box: AABB = room.get_trigger_box()
	for attempt: int in ATTEMPTS_PER_PROP:
		var local: Vector3 = Vector3(rng.randf_range(box.position.x, box.end.x), box.end.y - 0.2, rng.randf_range(box.position.z, box.end.z))
		var top: Vector3 = room.to_global(local)
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * (box.size.y + 1.0), WORLD_MASK))
		if hit.is_empty() or (hit["normal"] as Vector3).y < FLAT_NORMAL:
			continue
		var point: Vector3 = hit["position"]
		if not _is_flat(point, space) or _too_close(point, avoid, settings.entrance_clearance) or _too_close(point, taken, settings.min_spacing):
			continue
		if not _is_clear(point, space):
			continue
		return point
	return null


# Четыре пробы вокруг точки лежат на одной высоте: опора ровная.
static func _is_flat(point: Vector3, space: PhysicsDirectSpaceState3D) -> bool:
	for offset: Vector3 in [Vector3(PROBE_OFFSET, 0.0, 0.0), Vector3(-PROBE_OFFSET, 0.0, 0.0), Vector3(0.0, 0.0, PROBE_OFFSET), Vector3(0.0, 0.0, -PROBE_OFFSET)]:
		var from: Vector3 = point + offset + Vector3.UP * 0.5
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.5, WORLD_MASK))
		if hit.is_empty() or absf((hit["position"] as Vector3).y - point.y) > FLAT_TOLERANCE:
			return false
	return true


static func _too_close(point: Vector3, others: Array[Vector3], distance: float) -> bool:
	for other: Vector3 in others:
		if Vector2(other.x - point.x, other.z - point.z).length() < distance and absf(other.y - point.y) < 3.0:
			return true
	return false


# Над точкой нет стен и других тел (цилиндр с запасом).
static func _is_clear(point: Vector3, space: PhysicsDirectSpaceState3D) -> bool:
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = FOOTPRINT_RADIUS
	shape.height = FOOTPRINT_HEIGHT
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP * (FOOTPRINT_HEIGHT * 0.5 + 0.08))
	query.collision_mask = BLOCK_MASK
	return space.intersect_shape(query, 1).is_empty()


# Свободная плоская точка для укрытия: опора ровная по углам основания, вокруг есть проход шириной cover_walk_margin.
static func _find_cover_spot(room: RoomPiece, rng: RandomNumberGenerator, avoid: Array[Vector3], spawns: Array[Vector3], taken: Array[Vector3], settings: PropSettings, space: PhysicsDirectSpaceState3D, definition: CoverDefinition, yaw: float) -> Variant:
	var box: AABB = room.get_trigger_box()
	var extent: float = maxf(definition.size.x, definition.size.z) * 0.5
	for attempt: int in ATTEMPTS_PER_PROP:
		var local: Vector3 = Vector3(rng.randf_range(box.position.x, box.end.x), box.end.y - 0.2, rng.randf_range(box.position.z, box.end.z))
		var top: Vector3 = room.to_global(local)
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * (box.size.y + 1.0), WORLD_MASK))
		if hit.is_empty() or (hit["normal"] as Vector3).y < FLAT_NORMAL:
			continue
		var point: Vector3 = hit["position"]
		if _too_close(point, avoid, settings.entrance_clearance) or _too_close(point, spawns, settings.cover_spawn_clearance) or _too_close(point, taken, settings.min_spacing + extent * 2.0):
			continue
		if not _is_flat_footprint(point, space, definition.size, yaw) or not _is_clear_footprint(point, space, definition.size, yaw, settings.cover_walk_margin):
			continue
		return point
	return null


# Углы основания лежат на одной высоте с центром.
static func _is_flat_footprint(point: Vector3, space: PhysicsDirectSpaceState3D, size: Vector3, yaw: float) -> bool:
	var basis: Basis = Basis(Vector3.UP, yaw)
	for corner: Vector3 in [Vector3(size.x, 0.0, size.z), Vector3(-size.x, 0.0, size.z), Vector3(size.x, 0.0, -size.z), Vector3(-size.x, 0.0, -size.z)]:
		var from: Vector3 = point + basis * (corner * 0.5) + Vector3.UP * 0.5
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 1.5, WORLD_MASK))
		if hit.is_empty() or absf((hit["position"] as Vector3).y - point.y) > FLAT_TOLERANCE:
			return false
	return true


# Над основанием, расширенным на margin со всех сторон, нет стен и других тел.
static func _is_clear_footprint(point: Vector3, space: PhysicsDirectSpaceState3D, size: Vector3, yaw: float, margin: float) -> bool:
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(size.x + margin * 2.0, size.y, size.z + margin * 2.0)
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis(Vector3.UP, yaw), point + Vector3.UP * (size.y * 0.5 + 0.08))
	query.collision_mask = BLOCK_MASK
	return space.intersect_shape(query, 1).is_empty()


static func _pick_cover(rng: RandomNumberGenerator, settings: PropSettings) -> CoverDefinition:
	var total: float = 0.0
	for definition: CoverDefinition in settings.cover:
		total += definition.weight
	var pick: float = rng.randf() * total
	for definition: CoverDefinition in settings.cover:
		pick -= definition.weight
		if pick <= 0.0:
			return definition
	return settings.cover[settings.cover.size() - 1]


static func _pick_barrel(rng: RandomNumberGenerator, settings: PropSettings) -> BarrelDefinition:
	var total: float = 0.0
	for definition: BarrelDefinition in settings.barrels:
		total += definition.weight
	var pick: float = rng.randf() * total
	for definition: BarrelDefinition in settings.barrels:
		pick -= definition.weight
		if pick <= 0.0:
			return definition
	return settings.barrels[settings.barrels.size() - 1]


static func _pick_crate(rng: RandomNumberGenerator, settings: PropSettings) -> CrateDefinition:
	var total: float = 0.0
	for definition: CrateDefinition in settings.crates:
		total += definition.weight
	var pick: float = rng.randf() * total
	for definition: CrateDefinition in settings.crates:
		pick -= definition.weight
		if pick <= 0.0:
			return definition
	return settings.crates[settings.crates.size() - 1]
