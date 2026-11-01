@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: каждая комната пула по отдельности (№81): точки появления врагов, награды и игрока стоят на свободном месте и
## на земле, все входы комнаты связаны друг с другом проходом по навигации (в том числе подъём на высокий вход), точки
## появления достижимы от входа, вертикальные проёмы (шахты) и их площадки достижимы. Ловит враг внутри блока (комната
## не открывается) и недостижимые места (нет пути между входами).
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_rooms.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.

var _fails: int = 0
var _settings: ZoneSettings


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _initialize() -> void:
	create_timer(600.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	_settings = root.get_node("Config").data.zones
	for definition: RoomDefinition in RoomCatalog.load_all():
		if definition.kind == RoomDefinition.Kind.CORRIDOR:
			continue
		await _audit(definition)
	print("=== FAILS: ", _fails)
	quit(_fails)


func _audit(definition: RoomDefinition) -> void:
	var title: String = definition.resource_path.get_file().get_basename()
	print("--- ", title)
	var room: RoomPiece = definition.scene.instantiate() as RoomPiece
	root.add_child(room)
	var region: NavigationRegion3D = NavigationRegion3D.new()
	var started: int = Time.get_ticks_msec()
	region.navigation_mesh = NavigationBaker.bake(room, _settings)
	root.add_child(region)
	var map: RID = root.get_world_3d().navigation_map
	await _wait_navigation(map, region)
	var bake_ms: int = Time.get_ticks_msec() - started
	var space: PhysicsDirectSpaceState3D = room.get_world_3d().direct_space_state
	var info: RoomInfo = RoomCatalog.info_of(definition)
	var bounds: AABB = info.bounds
	print("INFO  габариты %s, входов %d, запекание %d мс, полигонов %d" % [str(bounds.size), info.entrances.size(), bake_ms, region.navigation_mesh.get_polygon_count()])

	# Входы: у каждого горизонтального вход внутри комнаты лежит на сетке навигации, все связаны между собой.
	var inside: Array[Vector3] = []
	for entrance: RoomInfo.Entrance in info.entrances:
		if entrance.is_vertical():
			continue
		var point: Vector3 = NavigationServer3D.map_get_closest_point(map, entrance.position - entrance.direction * 1.5)
		inside.append(point)
	var loose: PackedStringArray = []
	for i: int in inside.size():
		for j: int in range(i + 1, inside.size()):
			var path: PackedVector3Array = NavigationServer3D.map_get_path(map, inside[i], inside[j], true)
			if path.size() < 2 or path[path.size() - 1].distance_to(inside[j]) > 1.5:
				loose.append("%d-%d" % [i, j])
	_check(loose.is_empty(), "%s: все %d входа связаны проходом по навигации друг с другом %s" % [title, inside.size(), str(loose)])

	# Точки появления: свободное место, земля под ногами, достижимость от первого входа.
	var problems: PackedStringArray = []
	var total: int = 0
	var shape: CapsuleShape3D = CapsuleShape3D.new()
	shape.radius = 0.5
	shape.height = 1.8
	for group: String in ["enemy_spawn", "loot_spawn", "player_spawn"]:
		for marker: Marker3D in room.get_markers(group):
			total += 1
			var at: Vector3 = marker.global_position
			var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform = Transform3D(Basis.IDENTITY, at + Vector3(0.0, 1.0, 0.0))
			query.collision_mask = 1
			if not space.intersect_shape(query, 1).is_empty():
				problems.append("%s внутри геометрии %s" % [marker.name, str(at)])
				continue
			var ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(at + Vector3(0.0, 0.5, 0.0), at + Vector3(0.0, -1.5, 0.0), 1)
			if space.intersect_ray(ray).is_empty():
				problems.append("%s без земли под ногами %s" % [marker.name, str(at)])
				continue
			if group == "enemy_spawn" and not inside.is_empty():
				var snapped: Vector3 = NavigationServer3D.map_get_closest_point(map, at)
				var path: PackedVector3Array = NavigationServer3D.map_get_path(map, inside[0], snapped, true)
				if Vector2(snapped.x - at.x, snapped.z - at.z).length() > 1.2 or absf(snapped.y - at.y) > 1.5:
					problems.append("%s вне сетки навигации %s" % [marker.name, str(at)])
				elif path.size() < 2 or path[path.size() - 1].distance_to(snapped) > 1.5:
					problems.append("%s недостижима от входа %s" % [marker.name, str(at)])
	_check(problems.is_empty(), "%s: %d точек появления на свободной земле и достижимы %s" % [title, total, str(problems)])
	if definition.kind == RoomDefinition.Kind.COMBAT:
		_check(room.get_markers(&"enemy_spawn").size() >= 8, "%s: точек появления врагов достаточно (%d)" % [title, room.get_markers(&"enemy_spawn").size()])

	# Вертикальные проёмы. Потолочный: площадка перед проёмом (куда приходит пандус комнаты и откуда начинается лестница
	# стыка) достижима от входов. Проём в полу: по оси проёма нет пола, вокруг него пол на запас в 2 м (лестница стыка
	# выходит на пол этой комнаты в любую из сторон).
	for i: int in info.entrances.size():
		var entrance: RoomInfo.Entrance = info.entrances[i]
		if not entrance.is_vertical():
			continue
		var heading: Vector3 = entrance.heading()
		var across: Vector3 = Vector3.UP.cross(heading)
		var half_along: float = entrance.size.x * 0.5
		var half_across: float = entrance.size.y * 0.5
		if entrance.direction.y > 0.0:
			var lane: Vector3 = entrance.position - heading * (half_along + 1.0) + across * (half_across * 0.5) + Vector3(0.0, -4.6, 0.0)
			var near: Vector3 = NavigationServer3D.map_get_closest_point(map, lane)
			var route: PackedVector3Array = NavigationServer3D.map_get_path(map, inside[0], near, true) if not inside.is_empty() else PackedVector3Array()
			var close: bool = Vector2(near.x - lane.x, near.z - lane.z).length() < 1.5 and absf(near.y - lane.y) < 1.5
			_check(close and route.size() >= 2 and route[route.size() - 1].distance_to(near) < 1.5, "%s: к площадке перед потолочным проёмом можно подняться от входа (площадка %s, ближайшая точка сетки %s)" % [title, str(lane), str(near)])
		else:
			var hit_axis: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(entrance.position + Vector3(0.0, 3.0, 0.0), entrance.position + Vector3(0.0, -0.5, 0.0), 1))
			var rim_ok: bool = true
			for offset: Vector3 in [heading * (half_along + 2.0), -heading * (half_along + 2.0), across * (half_across + 2.0), -across * (half_across + 2.0)]:
				var at: Vector3 = entrance.position + offset
				var ray: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(at.x, 1.0, at.z), Vector3(at.x, -1.0, at.z), 1))
				if ray.is_empty():
					rim_ok = false
			_check(hit_axis.is_empty() and rim_ok, "%s: проём в полу открыт по оси, пол вокруг проёма на запас в 2 м" % title)
	region.free()
	room.free()
	await _frames(3)


# Карта навигации подхватывает новый регион не сразу: пока он не виден, запросы возвращают пустоту (нулевую точку).
func _wait_navigation(map: RID, region: NavigationRegion3D) -> void:
	var deadline: int = Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		await physics_frame
		# Ближайшая точка сетки должна принадлежать именно этому региону, а не сетке прошлой комнаты.
		var closest: Vector3 = NavigationServer3D.map_get_closest_point(map, Vector3(0.0, 0.1, 0.0))
		if closest != Vector3.ZERO and NavigationServer3D.map_get_closest_point_owner(map, Vector3(0.0, 0.1, 0.0)) == region.get_rid():
			break
	await _frames(2)
