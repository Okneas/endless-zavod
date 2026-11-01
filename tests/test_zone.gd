@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: зона в игре (срез 6, №81): сцена run/run.tscn строит зону из плана, заглушки и двери, лестницы
## вертикальных стыков, сетка навигации и проходимость (пандусы, стыки, физический проход капсулой игрока по всем комнатам),
## игрок на старте, бой в комнате с врагами (двери закрываются и открываются, враги стоят на свободной земле), сторож
## боя (провалившийся и застрявший враг переносятся), кладовая с лутом, преследующий враг идёт по навигации, смена зоны.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_zone.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.

var _fails: int = 0
var _scene: Node
var _builder
var _player
var _config
var _settings: ZoneSettings


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _wait_built() -> void:
	# Зона строится вместе с ожиданием карты навигации: в крупной зоне это тысячи кадров.
	for i: int in 20000:
		await process_frame
		if _scene.layout != null and not _scene._busy:
			break
	await _frames(5)


func _initialize() -> void:
	create_timer(900.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	_config = root.get_node("Config")
	_settings = _config.data.zones
	_settings.debug_seed = 4242
	root.size = Vector2i(1920, 1080)
	_scene = (load("res://run/run.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	_builder = _scene.get_node("Zone")
	_player = _scene.get_node("Player")
	# Стрелки есть уже в первой зоне и могут убить стоящего среди них игрока, а смерть в забеге ставит дерево на паузу (экран итогов):
	# остальные проверки зоны шли бы вхолостую. Здание зоны проверяется не на выживание, поэтому здоровье возвращается при каждом уроне
	# (в сигнале урона, до проверки на смерть).
	_player.damaged.connect(func(_amount: float, _from: Vector3) -> void: _player.set_health(_player.max_health))
	await _wait_built()
	await _test_build()
	await _test_navigation()
	await _test_walk()
	await _test_combat()
	await _test_watchdog()
	await _test_loot()
	await _test_chaser()
	await _test_zones()
	print("=== FAILS: ", _fails)
	quit(_fails)


func _find_piece(kind: int):
	for piece: PlacedPiece in _builder.layout.pieces:
		if piece.kind() == kind:
			return piece
	return null


func _room_center(piece: PlacedPiece) -> Vector3:
	var bounds: AABB = _builder.pieces[piece.index].get_bounds()
	return _builder.pieces[piece.index].global_transform * (bounds.get_center() * Vector3(1, 0, 1) + Vector3(0, 0.3, 0))


# Точки внутри комнаты, куда обязательно должен дойти игрок: входы изнутри и точки появления врагов и награды.
func _room_points(piece: PlacedPiece) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var room: RoomPiece = _builder.pieces[piece.index]
	for entrance: RoomInfo.Entrance in piece.info.entrances:
		if not entrance.is_vertical():
			result.append(piece.transform * (entrance.position - entrance.direction * 1.5))
	for group: String in ["enemy_spawn", "loot_spawn"]:
		for marker: Marker3D in room.get_markers(group):
			result.append(marker.global_position)
	return result


# Сколько стыков, где комната стоит над комнатой.
func _joint_count(layout: ZoneLayout) -> int:
	var total: int = 0
	for piece: PlacedPiece in layout.pieces:
		for entrance: int in piece.links:
			if piece.info.entrances[entrance].is_vertical() and piece.info.entrances[entrance].direction.y > 0.0:
				total += 1
	return total


# Комната с боем, у которой есть двери (горизонтальные входы с соседом), иначе первая с боем.
func _combat_piece(with_doors: bool) -> PlacedPiece:
	var fallback: PlacedPiece = null
	for piece: PlacedPiece in _builder.layout.pieces:
		if piece.kind() != RoomDefinition.Kind.COMBAT:
			continue
		if fallback == null:
			fallback = piece
		for controller in _builder.controllers:
			if controller.room == _builder.pieces[piece.index] and not controller.doors.is_empty() and with_doors:
				return piece
	return fallback


# Куда ставить игрока, чтобы бой в комнате начался: точка на полу внутри зоны входа (не центр комнаты, он у части комнат
# внутри плиты или колонны, и из такой точки по навигации никуда не дойти).
func _trigger_point(piece: PlacedPiece) -> Vector3:
	var room: RoomPiece = _builder.pieces[piece.index]
	var best: Vector3 = _room_center(piece)
	var best_y: float = INF
	var center: Vector3 = _room_center(piece)
	for marker: Marker3D in room.get_markers(&"enemy_spawn"):
		var point: Vector3 = marker.global_position
		var rank: float = point.y * 1000.0 + Vector2(point.x - center.x, point.z - center.z).length()
		if rank < best_y:
			best_y = rank
			best = point + Vector3(0.0, 0.1, 0.0)
	return best


func _wait_navigation() -> void:
	var map: RID = _scene.get_world_3d().navigation_map
	for i: int in 240:
		await physics_frame
		if NavigationServer3D.map_get_regions(map).size() == 1 and NavigationServer3D.map_get_closest_point(map, Vector3(0.0, 0.5, 0.0)) != Vector3.ZERO:
			break
	await _frames(3)


# --- Сборка зоны.
func _test_build() -> void:
	print("--- Сборка зоны")
	var layout: ZoneLayout = _builder.layout
	_check(layout != null and layout.warnings.is_empty() and layout.zone_number == 1, "зона 1 собрана без замечаний: %s" % layout.describe())
	var joints: int = _joint_count(layout)
	_check(_builder.pieces.size() == layout.pieces.size() and _builder.get_node("Pieces").get_child_count() == layout.pieces.size() + _builder.links.size(), "на сцене %d частей плана и %d лестниц стыков" % [_builder.pieces.size(), _builder.links.size()])
	_check(_builder.links.size() == joints, "лестница стоит в каждом вертикальном стыке (%d)" % joints)
	var placed_ok: bool = true
	for piece: PlacedPiece in layout.pieces:
		if not _builder.pieces[piece.index].global_transform.is_equal_approx(piece.transform):
			placed_ok = false
	_check(placed_ok, "каждая часть стоит там, где её поставил генератор")
	_check(_builder.plugs.size() == layout.open_entrance_count(), "глухих проёмов %d, у каждого заглушка" % layout.open_entrance_count())
	var plugs_closed: bool = true
	for plug in _builder.plugs:
		if not plug.is_closed or not plug.is_plug or plug.collision_layer != 1:
			plugs_closed = false
	_check(plugs_closed, "заглушки закрыты и непроходимы")
	var combat_rooms: int = layout.count(RoomDefinition.Kind.COMBAT)
	var expected_doors: int = 0
	var vertical_doors: int = 0
	for piece: PlacedPiece in layout.pieces:
		if piece.kind() in [RoomDefinition.Kind.COMBAT, RoomDefinition.Kind.GATE, RoomDefinition.Kind.EVACUATION, RoomDefinition.Kind.BOSS]:
			# Двери (плиты) стоят на каждом входе с соседом, и на горизонтальных, и на вертикальных стыках (№85).
			expected_doors += piece.links.size()
			for entrance: int in piece.links:
				if piece.info.entrances[entrance].is_vertical():
					vertical_doors += 1
	var doors_open: bool = true
	for door in _builder.doors:
		if door.is_closed or door.collision_layer != 0:
			doors_open = false
	_check(combat_rooms > 0 and _builder.doors.size() == expected_doors and doors_open, "дверь на каждом входе с соседом (в стене и на стыке вверх или вниз, вертикальных %d) у %d комнат с боем (%d), до боя открыты" % [vertical_doors, combat_rooms, _builder.doors.size()])
	_check(_builder.controllers.size() == combat_rooms + layout.count(RoomDefinition.Kind.LOOT), "контроллеры есть у комнат с боем и кладовых (%d)" % _builder.controllers.size())
	var labels: int = 0
	for room in _builder.pieces:
		if room.has_node("Label"):
			labels += 1
	_check(labels == layout.room_count(), "у каждой комнаты пометка типа (%d)" % labels)
	var spawn: Marker3D = _builder.player_spawn
	_check(spawn != null and _player.global_position.distance_to(spawn.global_position) < 1.0, "игрок поставлен на старт")
	# Игрок появляется чуть над полом и приземляется за 30-40 кадров: ждём приземления, но не дольше секунды.
	for i: int in 120:
		if i >= 30 and _player.is_on_floor():
			break
		await physics_frame
	_check(_player.is_on_floor(), "игрок стоит на полу стартовой комнаты")
	_check(not _scene.get_node("Loading").visible and _scene.get_node("Status/Label").text.contains(str(layout.zone_seed)), "экран загрузки убран, в строке состояния сид %d" % layout.zone_seed)
	_check(layout.zone_level == ZoneMath.zone_level(_settings, _settings.world_level_start, 1), "уровень зоны %d по формуле" % layout.zone_level)


# --- Навигация.
func _test_navigation() -> void:
	print("--- Навигация")
	var region: NavigationRegion3D = _builder.navigation_region
	_check(region != null and region.navigation_mesh != null and region.navigation_mesh.get_polygon_count() > 0, "сетка навигации запечена (%d полигонов)" % region.navigation_mesh.get_polygon_count())
	await _wait_navigation()
	var map: RID = _scene.get_world_3d().navigation_map
	var start: Vector3 = _builder.player_spawn.global_position
	var unreachable: PackedStringArray = []
	var points: int = 0
	for piece: PlacedPiece in _builder.layout.pieces:
		if piece.is_corridor():
			continue
		for point: Vector3 in _room_points(piece):
			points += 1
			var target: Vector3 = NavigationServer3D.map_get_closest_point(map, point)
			var path: PackedVector3Array = NavigationServer3D.map_get_path(map, start, target, true)
			if Vector2(target.x - point.x, target.z - point.z).length() > 1.5 or absf(target.y - point.y) > 1.8 or path.size() < 2 or path[path.size() - 1].distance_to(target) > 1.5:
				unreachable.append("%s %s" % [piece.definition.resource_path.get_file(), str(point)])
	_check(unreachable.is_empty(), "от старта по навигации можно дойти до каждой из %d точек комнат (входы, точки появления врагов и награды), в том числе по пандусам и стыкам, %d стыков %s" % [points, _joint_count(_builder.layout), str(unreachable)])
	_check(_builder.layout.get_bounds().size.y >= 6.0, "зона вертикальна: перепад высот %.0f м" % _builder.layout.get_bounds().size.y)


# Тело с капсулой игрока идёт по пути навигации физически (стены, пандусы, заглушки, двери). Сетка навигации разрешает
# ступеньки до одной ячейки высоты (0.3 м), а капсула без прыжка берёт только около 0.1 м, поэтому при застревании тело
# прыгает, как игрок (прыжок игрока 1.9 м). Возвращает остаток расстояния до цели по горизонтали и по вертикали и число
# прыжков: если их много, на пути настоящая преграда, а не ступенька.
func _walk(from: Vector3, to: Vector3, speed: float) -> Vector3:
	var map: RID = _scene.get_world_3d().navigation_map
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, to, true)
	var body: CharacterBody3D = CharacterBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1
	body.floor_max_angle = deg_to_rad(45.0)
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	var shape: CollisionShape3D = CollisionShape3D.new()
	shape.shape = capsule
	shape.position.y = 0.9
	body.add_child(shape)
	_scene.add_child(body)
	body.global_position = from + Vector3(0.0, 0.05, 0.0)
	var frames_left: int = 120 * 400
	var jumps: int = 0
	var stalled: int = 0
	for i: int in range(1, path.size()):
		var goal: Vector3 = path[i]
		while frames_left > 0:
			var flat: Vector3 = Vector3(goal.x - body.global_position.x, 0.0, goal.z - body.global_position.z)
			if flat.length() < 0.5:
				break
			var before: Vector3 = body.global_position
			body.velocity.x = flat.normalized().x * speed
			body.velocity.z = flat.normalized().z * speed
			body.velocity.y = 0.0 if body.is_on_floor() else body.velocity.y - 30.0 / 120.0
			if stalled >= 20 and body.is_on_floor():
				body.velocity.y = 6.0
				stalled = 0
				jumps += 1
			body.move_and_slide()
			await physics_frame
			frames_left -= 1
			if Vector2(body.global_position.x - before.x, body.global_position.z - before.z).length() < speed / 120.0 * 0.3:
				stalled += 1
			else:
				stalled = 0
	var left: Vector3 = to - body.global_position
	body.queue_free()
	return Vector3(Vector2(left.x, left.z).length(), absf(left.y), float(jumps))


# --- Физический проход.
func _test_walk() -> void:
	print("--- Физический проход капсулой игрока")
	var layout: ZoneLayout = _builder.layout
	var start: Vector3 = _builder.player_spawn.global_position
	var map: RID = _scene.get_world_3d().navigation_map
	var failed: PackedStringArray = []
	var walked: int = 0
	var total_distance: float = 0.0
	var total_jumps: int = 0
	for piece: PlacedPiece in layout.pieces:
		if piece.is_corridor():
			continue
		var targets: Array[Vector3] = _room_points(piece)
		if targets.is_empty():
			continue
		# По одной точке на комнату: последняя в списке (точка на площадке или в глубине), чтобы путь шёл через всю комнату.
		var target: Vector3 = NavigationServer3D.map_get_closest_point(map, targets[targets.size() - 1])
		var path: PackedVector3Array = NavigationServer3D.map_get_path(map, start, target, true)
		for i: int in range(1, path.size()):
			total_distance += path[i].distance_to(path[i - 1])
		var left: Vector3 = await _walk(start, target, 6.0)
		walked += 1
		total_jumps += int(left.z)
		if left.x > 1.5 or left.y > 2.0:
			failed.append("%s: осталось %.1f м по горизонтали, %.1f м по высоте" % [piece.definition.resource_path.get_file(), left.x, left.y])
	_check(failed.is_empty() and walked > 0, "капсула игрока физически дошла от старта до %d комнат (около %.0f м пути, в том числе через стыки комнат друг над другом) %s" % [walked, total_distance, str(failed)])
	_check(total_jumps <= walked * 2, "по пути понадобилось мало прыжков через ступеньки сетки навигации: %d на %d маршрутов" % [total_jumps, walked])


# --- Комната с боем.
func _test_combat() -> void:
	print("--- Бой в комнате")
	var piece: PlacedPiece = _combat_piece(true)
	var controller = null
	for candidate in _builder.controllers:
		if candidate.room == _builder.pieces[piece.index]:
			controller = candidate
	_check(controller != null and controller.state == 0, "у первой боевой комнаты контроллер ждёт игрока")
	var started: Dictionary = {"count": 0, "cleared": 0}
	controller.combat_started.connect(func() -> void: started["count"] += 1)
	controller.combat_cleared.connect(func() -> void: started["cleared"] += 1)
	_player.global_position = _trigger_point(piece)
	await _frames(20)
	var expected: int = maxi(roundi(float(ZoneMath.enemy_count(_settings, 1)) * piece.definition.enemy_scale), 1)
	_check(controller.state == 1 and started["count"] == 1, "игрок вошёл: бой начался")
	_check(controller.enemies_alive == expected, "появилось %d врагов по формуле зоны на множитель комнаты %.2f" % [controller.enemies_alive, piece.definition.enemy_scale])
	var closed: bool = true
	for door in controller.doors:
		if not door.is_closed or door.collision_layer != 1:
			closed = false
	_check(closed and not controller.doors.is_empty(), "двери комнаты (%d) закрылись" % controller.doors.size())
	var enemies: Array = []
	for child: Node in _builder.pieces[piece.index].get_children():
		if child is CharacterBody3D and child != _player:
			enemies.append(child)
	_check(enemies.size() == expected, "враги стоят в комнате (%d)" % enemies.size())
	var kinds: Dictionary = {}
	for enemy in enemies:
		kinds[enemy.scene_file_path.get_file()] = true
	var pool_ok: bool = true
	for key: String in kinds:
		var found: bool = false
		for entry: EnemyPoolEntry in _settings.enemy_pool:
			if entry.scene != null and entry.scene.resource_path.get_file() == key and entry.min_zone <= 1:
				found = true
		if not found:
			pool_ok = false
	_check(pool_ok, "враги из пула зоны: %s" % str(kinds.keys()))
	# Появление: каждый враг свободен (не в геометрии), наземные на земле у сетки навигации, никто не вплотную к другому.
	var map: RID = _scene.get_world_3d().navigation_map
	var bad: PackedStringArray = []
	var closest: float = 1000.0
	for enemy in enemies:
		# Классы врагов по имени: скрипт теста грузится раньше автозагрузок и не может ссылаться на них напрямую.
		var flying: bool = enemy.is_flier()
		# Приподнимаем на 0.15 м: враг уже опустился на пол, и касание пола не считается застреванием.
		if enemy.test_move(enemy.global_transform.translated(Vector3(0.0, 0.15, 0.0)), Vector3.ZERO, null, 0.001, true):
			bad.append("%s внутри геометрии" % enemy.name)
		if not flying:
			var near: Vector3 = NavigationServer3D.map_get_closest_point(map, enemy.global_position)
			if Vector2(near.x - enemy.global_position.x, near.z - enemy.global_position.z).length() > 1.5 or absf(near.y - enemy.global_position.y) > 1.5:
				bad.append("%s вне сетки навигации" % enemy.name)
		for other in enemies:
			if other != enemy:
				closest = minf(closest, other.global_position.distance_to(enemy.global_position))
	_check(bad.is_empty() and closest >= _settings.spawn_spacing - 0.01, "враги стоят на свободном месте, на земле у сетки навигации; ближайшие друг к другу в %.1f м (минимум %.1f) %s" % [closest, _settings.spawn_spacing, str(bad)])
	var alert_ok: bool = true
	for enemy in enemies:
		if enemy.always_aggro != _settings.combat_alert_all:
			alert_ok = false
	_check(alert_ok, "враги знают, где игрок, с начала боя, если это включено в настройках (%s)" % str(_settings.combat_alert_all))
	for enemy in enemies:
		enemy.take_hit(DamageInfo.create(100000.0, false, enemy.global_position + Vector3(0, 1, 0)))
	await _frames(10)
	_check(controller.state == 2 and started["cleared"] == 1 and controller.enemies_alive == 0, "все враги убиты: бой закончен")
	var opened: bool = true
	for door in controller.doors:
		if door.is_closed or door.collision_layer != 0:
			opened = false
	_check(opened, "двери открылись")
	_player.global_position = _builder.player_spawn.global_position
	await _frames(10)
	_check(started["count"] == 1, "повторно бой не начинается")


# --- Сторож боя: враг, провалившийся под зону, и враг, застрявший в полу, переносятся на свободное место.
func _test_watchdog() -> void:
	print("--- Сторож боя")
	var controller = null
	for candidate in _builder.controllers:
		if candidate.kind == RoomDefinition.Kind.COMBAT and candidate.state == 0:
			controller = candidate
	if controller == null:
		# Все боевые комнаты этой зоны уже отыграны (комнат мало): берём одну и сбрасываем её в ожидание игрока.
		for candidate in _builder.controllers:
			if candidate.kind == RoomDefinition.Kind.COMBAT:
				controller = candidate
		if controller == null:
			_check(false, "для проверки сторожа нужна комната с боем")
			return
		controller.state = 0
		controller.director.enemies.clear()
		controller.director.enemies_alive = 0
	var room: RoomPiece = controller.room
	var room_piece: PlacedPiece = null
	for candidate: PlacedPiece in _builder.layout.pieces:
		if _builder.pieces[candidate.index] == room:
			room_piece = candidate
	_player.global_position = _trigger_point(room_piece)
	await _frames(20)
	_check(controller.state == 1 and controller.enemies_alive > 1, "бой начался, врагов %d" % controller.enemies_alive)
	# Усыплённых (№87) сторож не трогает, а пробуждение включает им физику обратно: ждём, пока все проснутся, и только потом портим.
	await _frames(int(_config.data.run.spawn_warning_time * 120.0) + 40)
	var fallen = controller.enemies[0]
	var buried = controller.enemies[controller.enemies.size() - 1]
	var floor_y: float = _builder.layout.get_bounds().position.y
	fallen.global_position = Vector3(fallen.global_position.x, floor_y - _settings.fall_margin - 50.0, fallen.global_position.z)
	# Застрявшему отключаем физику, иначе тело само выталкивает себя из пола: нужно проверить именно сторож.
	buried.set_physics_process(false)
	buried.global_position = room.global_transform * Vector3(0.0, -1.0, 0.0)
	var buried_at: Vector3 = buried.global_position
	await _frames(int(_settings.watchdog_interval * 120.0 * 6.0))
	_check(fallen.global_position.y > floor_y - _settings.fall_margin, "провалившийся под зону враг возвращён в комнату (y %.1f)" % fallen.global_position.y)
	_check(buried.global_position.distance_to(buried_at) > 2.0, "застрявший в полу враг перенесён на свободное место (на %.1f м)" % buried.global_position.distance_to(buried_at))
	_check(controller.relocations >= 2, "сторож перенёс врагов: %d раз" % controller.relocations)
	for enemy in controller.enemies.duplicate():
		enemy.set_physics_process(false)
		enemy.take_hit(DamageInfo.create(100000.0, false, enemy.global_position + Vector3(0, 1, 0)))
	await _frames(10)
	_check(controller.state == 2 and controller.enemies_alive == 0, "после гибели всех врагов бой закончен")


# --- Кладовая.
func _test_loot() -> void:
	print("--- Кладовая")
	var piece: PlacedPiece = _find_piece(RoomDefinition.Kind.LOOT)
	if piece == null:
		_check(false, "в зоне нет кладовой")
		return
	var markers: int = _builder.pieces[piece.index].get_markers(&"loot_spawn").size()
	var money_before: int = root.get_node("Progress").money
	var before: int = _pickups_in(_builder.pieces[piece.index]).size()
	_player.global_position = _room_center(piece)
	await _frames(30)
	# Только предметы этой комнаты: в других (магазин выкладывает предметы на постаменты сразу при постройке) они не считаются.
	var found: Array = _pickups_in(_builder.pieces[piece.index])
	var weapons: Array = found.filter(func(pickup) -> bool: return pickup.item.is_weapon())
	var parts: Array = found.filter(func(pickup) -> bool: return pickup.item.is_part())
	# Оружие выпадает по шансу loot_weapon_chance (дефицит, №85): не больше числа оружейных точек, при шансе 1 ровно столько.
	var weapon_points: int = mini(_settings.loot_weapons, markers)
	_check(before == 0 and weapons.size() <= weapon_points and (_settings.loot_weapon_chance < 1.0 or weapons.size() == weapon_points), "в кладовой оружия %d из %d оружейных точек (шанс %.2f, точек награды %d)" % [weapons.size(), weapon_points, _settings.loot_weapon_chance, markers])
	_check(parts.size() == clampi(markers - _settings.loot_weapons, 0, _settings.loot_parts), "и детали оружия отдельными предметами: %d из %d по настройке" % [parts.size(), _settings.loot_parts])
	var level_ok: bool = true
	for pickup in weapons:
		if pickup.item.get_level() != _builder.layout.zone_level:
			level_ok = false
	_check(level_ok, "уровень оружия равен уровню зоны %d" % _builder.layout.zone_level)
	var money: int = 0
	var junk: int = 0
	var gained: int = root.get_node("Progress").money - money_before
	for child: Node in _builder.pieces[piece.index].get_children():
		if child.get_script() != null and child.get_script().get_global_name() == "Pickup":
			money += 1
		# Хлам (№91) иногда лежит вместо монет на точке денег.
		elif child.get_script() != null and child.get_script().get_global_name() == "ItemPickup" and child.item.definition != null and child.item.definition.category == ItemDefinition.Category.JUNK:
			junk += 1
	# Часть монет игрок успевает подобрать сам (магнит), поэтому смотрим и остаток на полу, и прирост денег.
	var money_points: int = maxi(markers - weapons.size() - parts.size(), 0)
	_check(money + junk <= money_points and (money_points == 0 or money + junk > 0 or gained >= _settings.loot_money_min), "остальные точки награды (%d) дают деньги или хлам: монет на полу %d, хлама %d, подобрано денег %d" % [money_points, money, junk, gained])
	_player.global_position = _builder.player_spawn.global_position
	await _frames(10)
	var again: int = get_nodes_in_group(&"item_pickups").size()
	_player.global_position = _room_center(piece)
	await _frames(30)
	_check(get_nodes_in_group(&"item_pickups").size() == again, "лут появляется один раз")


# Предметы-подбираемые (ItemPickup), лежащие прямо в комнате.
func _pickups_in(room: Node) -> Array:
	var result: Array = []
	for pickup: Node in get_nodes_in_group(&"item_pickups"):
		if pickup.get_parent() == room:
			result.append(pickup)
	return result


# --- Враг идёт по навигации.
func _test_chaser() -> void:
	print("--- Преследующий враг идёт по сетке навигации")
	var start: PlacedPiece = _builder.layout.get_start()
	var far: PlacedPiece = null
	for index: int in start.links.values():
		var corridor: PlacedPiece = _builder.layout.pieces[index]
		for entrance: int in corridor.links:
			var neighbour: PlacedPiece = _builder.layout.pieces[corridor.links[entrance]]
			if neighbour != start and far == null:
				far = neighbour
	var map: RID = _scene.get_world_3d().navigation_map
	var player_at: Vector3 = _builder.player_spawn.global_position
	var targets: Array[Vector3] = _room_points(far)
	var enemy_at: Vector3 = NavigationServer3D.map_get_closest_point(map, targets[targets.size() - 1])
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, enemy_at, player_at, true)
	var length: float = 0.0
	for i: int in range(1, path.size()):
		length += path[i].distance_to(path[i - 1])
	var chaser = (load("res://enemies/chaser.tscn") as PackedScene).instantiate()
	chaser.settings = chaser.settings.duplicate()
	chaser.settings.aggro_range = 500.0
	chaser.settings.melee_damage = 0.0
	_scene.add_child(chaser)
	chaser.global_position = enemy_at + Vector3(0, 0.2, 0)
	_player.global_position = player_at
	_player.velocity = Vector3.ZERO
	var seconds: float = length / chaser.settings.move_speed + 8.0
	var closest: float = 1000.0
	for tick: int in int(seconds * 120.0):
		await physics_frame
		_player.global_position = player_at
		closest = minf(closest, chaser.global_position.distance_to(player_at))
		if closest < 3.0:
			break
	_check(path.size() >= 2 and closest < 3.0 and chaser.get("_agent") != null, "враг прошёл путь %.0f м через комнаты и переходы и дошёл до игрока (ближе всего %.1f м)" % [length, closest])
	chaser.queue_free()


# --- Смена зоны и все зоны.
func _test_zones() -> void:
	print("--- Смена зоны")
	var problems: PackedStringArray = []
	var started: int = Time.get_ticks_msec()
	for zone_number: int in range(1, _settings.zones_in_department + 1):
		_scene.generate(zone_number)
		await _wait_built()
		var layout: ZoneLayout = _builder.layout
		var polygons: int = _builder.navigation_region.navigation_mesh.get_polygon_count() if _builder.navigation_region != null else 0
		if layout.zone_number != zone_number or not layout.warnings.is_empty() or polygons == 0 or _builder.pieces.size() != layout.pieces.size():
			problems.append("зона %d: %s, полигонов %d" % [zone_number, str(layout.warnings), polygons])
		if _builder.get_node("Pieces").get_child_count() != layout.pieces.size() + _builder.links.size():
			problems.append("зона %d: на сцене остались части прошлой зоны" % zone_number)
		if zone_number == _settings.zones_in_department and layout.count(RoomDefinition.Kind.BOSS) != 1:
			problems.append("в последней зоне нет босса")
		if _player.global_position.distance_to(_builder.player_spawn.global_position) > 1.0:
			problems.append("зона %d: игрок не на старте" % zone_number)
	_check(problems.is_empty(), "все %d зон строятся с сеткой навигации, игрок на старте %s" % [_settings.zones_in_department, str(problems)])
	print("INFO  построение и запекание зоны: в среднем %.0f мс" % (float(Time.get_ticks_msec() - started) / float(_settings.zones_in_department)))
	_scene.generate(2)
	await _wait_built()
	var seed_a: int = _builder.layout.zone_seed
	_scene.generate(2)
	await _wait_built()
	_check(seed_a == _builder.layout.zone_seed, "с фиксированным сидом зона повторяется (сид %d)" % seed_a)
