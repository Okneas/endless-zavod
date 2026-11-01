class_name Blast
extends RefCounted
## Общий взрыв по радиусу (№91, №92): бочки, гранаты игрока и взрыв подрывника. Задевает всё на слоях врагов и игрока в радиусе, если до
## центра цели есть прямая видимость: врагов, ящики и бочки (цепной взрыв), а игрока только с player_damage больше нуля. Урон падает от
## центра к краю до edge_share. Стихия накладывается на врагов через обычное попадание (take_hit).

const WORLD_LAYER: int = 1
const PLAYER_LAYER: int = 2
const ENEMY_LAYER: int = 4
## Доля радиуса вокруг центра, где урон полный.
const FULL_ZONE: float = 0.4


## Применяет взрыв. damage: урон врагам, ящикам и бочкам в центре (0 — им ничего). player_damage: урон игроку в центре (0 — игрока не
## задевает). exclude: тела, которые взрыв не трогает (сам источник). Возвращает число задетых целей.
static func apply(source: Node3D, origin: Vector3, radius: float, damage: float, element: CombatEnums.Element, edge_share: float, player_damage: float, exclude: Array[RID] = []) -> int:
	var space: PhysicsDirectSpaceState3D = source.get_world_3d().direct_space_state
	var shape: SphereShape3D = SphereShape3D.new()
	shape.radius = radius
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, origin)
	query.collision_mask = ENEMY_LAYER | PLAYER_LAYER
	query.exclude = exclude
	var seen: Dictionary = {}
	var hits: int = 0
	for result: Dictionary in space.intersect_shape(query, 64):
		var body: Object = result["collider"]
		if body == null or seen.has(body) or not body is Node3D:
			continue
		seen[body] = true
		var node: Node3D = body as Node3D
		var center: Vector3 = node.global_position + Vector3(0.0, 0.9, 0.0)
		var distance: float = origin.distance_to(center)
		if distance > radius + 0.9:
			continue
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(origin + Vector3(0.0, 0.3, 0.0), center, WORLD_LAYER)).is_empty():
			continue
		var falloff: float = lerpf(1.0, edge_share, clampf((distance - radius * FULL_ZONE) / (radius * (1.0 - FULL_ZONE)), 0.0, 1.0))
		if node.is_in_group(&"player"):
			if player_damage > 0.0:
				node.call(&"take_damage", player_damage * falloff, origin)
				hits += 1
		elif damage > 0.0 and node.has_method(&"chain_detonate"):
			node.call(&"chain_detonate")
			hits += 1
		elif damage > 0.0 and node.has_method(&"take_hit"):
			var info: DamageInfo = DamageInfo.create(damage * falloff, false, center)
			info.element = element
			info.apply_vulnerability = false
			node.call(&"take_hit", info)
			hits += 1
	return hits
