@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: много зон подряд (№81, №82). В каждой из 30 зон (все зоны отдела, по 3 сида) зона собирается как в игре и
## проверяется: от старта по навигации можно дойти до каждой точки каждой комнаты (входы, точки появления врагов и
## награды), в том числе через стыки комнат друг над другом; в каждой комнате с боем враги появляются на свободной земле
## у сетки навигации и после гибели всех двери открываются; в каждой третьей зоне капсула игрока физически проходит от
## старта до самой дальней комнаты. Ловит комнаты, которые не открываются, и места, куда нет связанного пути.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_zone_sweep.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.

const Walker = preload("res://tests/capsule_walker.gd")
const SEEDS: int = 3
const WALK_EVERY: int = 3
const WALK_SPEED: float = 8.0

var _fails: int = 0
var _settings: ZoneSettings
var _scene: Node
var _run_settings
var _wave_pause_before: float = 0.0
var _builder


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _secs(seconds: float) -> void:
	await _frames(int(seconds * 120.0))


func _initialize() -> void:
	create_timer(2400.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	_settings = root.get_node("Config").data.zones
	_run_settings = root.get_node("Config").data.run
	_wave_pause_before = _run_settings.wave_pause
	_run_settings.wave_pause = 0.2
	root.size = Vector2i(1920, 1080)
	# Зона строится сценой отладочного запуска, как в игре (скрипт теста не может ссылаться на классы с автозагрузками).
	_scene = (load("res://run/run.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	_builder = _scene.get_node("Zone")
	await _wait_built()
	var holder: Node = _scene
	var nav_problems: Dictionary = {}
	var combat_problems: Dictionary = {}
	var walk_problems: PackedStringArray = []
	var zones: int = 0
	var points: int = 0
	var joints: int = 0
	var rooms_fought: int = 0
	var vertical_locked: int = 0
	var vertical_open_in_fight: int = 0
	var challenges_run: int = 0
	var enemies_spawned: int = 0
	var enemy_kinds: Dictionary = {}
	var modified_seen: int = 0
	var modified_forbidden: PackedStringArray = []
	var walks: int = 0
	var jumps: int = 0
	var walked_distance: float = 0.0
	var slowest_ms: int = 0
	var total_ms: int = 0
	var started: int = Time.get_ticks_msec()
	for zone_number: int in range(1, _settings.zones_in_department + 1):
		for seed_index: int in SEEDS:
			_settings.debug_seed = 1000 + seed_index * 37
			# Сид забега задан, иначе зона эвакуации (а с ней и планировка) менялась бы от запуска к запуску.
			_scene.run_seed = 700 + seed_index
			var build_started: int = Time.get_ticks_msec()
			_scene.generate(zone_number)
			await _wait_built()
			var build_ms: int = Time.get_ticks_msec() - build_started
			slowest_ms = maxi(slowest_ms, build_ms)
			total_ms += build_ms
			var layout: ZoneLayout = _builder.layout
			zones += 1
			joints += _builder.links.size()
			await _wait_navigation()
			var map: RID = _scene.get_world_3d().navigation_map
			var start: Vector3 = _builder.player_spawn.global_position
			# Достижимость каждой точки каждой комнаты. Если есть недостижимые, ждём и проверяем ещё раз: карта навигации
			# после смены зоны могла не успеть обновиться.
			var report: Dictionary = _reachability(layout, map, start)
			points += int(report["points"])
			if not (report["problems"] as PackedStringArray).is_empty():
				await _frames(90)
				report = _reachability(layout, map, start)
				for line: String in report["problems"]:
					var key: String = "зона %d сид %d: %s" % [zone_number, seed_index, line]
					nav_problems[key] = 1
			var farthest: Vector3 = report["farthest"]
			var farthest_length: float = report["length"]
			# Бой в каждой комнате с боем.
			for controller in _builder.controllers:
				if controller.kind != RoomDefinition.Kind.COMBAT:
					continue
				controller.state = 1
				controller._start_combat()
				rooms_fought += 1
				await _frames(2)
				var piece_name: String = controller.room.name
				if controller.enemies_alive <= 0:
					_add(combat_problems, "%s: враги не появились" % piece_name)
				for door in controller.doors:
					if not door.is_closed:
						_add(combat_problems, "%s: дверь не закрылась в бою" % piece_name)
					if door.is_vertical:
						vertical_locked += 1
						if door.collision_layer != 1:
							vertical_open_in_fight += 1
				for enemy in controller.enemies:
					enemies_spawned += 1
					var kind: String = enemy.get_script().get_global_name()
					enemy_kinds[kind] = int(enemy_kinds.get(kind, 0)) + 1
					if enemy.modifier != null:
						modified_seen += 1
						if not enemy.settings.allows_modifier:
							modified_forbidden.append("%s: %s" % [controller.room.name, kind])
					var flying: bool = enemy.is_flier()
					if enemy.test_move(enemy.global_transform.translated(Vector3(0.0, 0.15, 0.0)), Vector3.ZERO, null, 0.001, true):
						_add(combat_problems, "%s: %s внутри геометрии" % [controller.room.name, kind])
					if not flying:
						var near: Vector3 = NavigationServer3D.map_get_closest_point(map, enemy.global_position)
						if Vector2(near.x - enemy.global_position.x, near.z - enemy.global_position.z).length() > 1.5 or absf(near.y - enemy.global_position.y) > 1.5:
							_add(combat_problems, "зона %d сид %d %s: наземный %s вне сетки навигации (в %s, ближайшая точка %s)" % [zone_number, seed_index, piece_name, kind, str(enemy.global_position), str(near)])
				for enemy in controller.enemies.duplicate():
					enemy.set_physics_process(false)
					enemy.take_hit(DamageInfo.create(1.0e9, false, enemy.global_position + Vector3(0, 1, 0)))
				await _frames(2)
				if controller.state != 2 or controller.enemies_alive != 0:
					_add(combat_problems, "%s: бой не закончился" % piece_name)
				for door in controller.doors:
					if door.is_closed:
						_add(combat_problems, "%s: дверь осталась закрытой" % piece_name)
			# Испытания (шлюз, эвакуация, босс): враги встают правильно, испытание проходится, двери и портал открываются.
			for challenge in _builder.challenges:
				var title: String = "зона %d сид %d %s" % [zone_number, seed_index, challenge.room.name]
				challenge.begin()
				await _frames(3)
				if challenge.director.enemies_alive <= 0 and challenge.state != 3:
					_add(combat_problems, "%s: испытание не дало врагов" % title)
				for enemy in challenge.director.enemies:
					var kind: String = enemy.get_script().get_global_name()
					if enemy.modifier != null:
						modified_seen += 1
						if not enemy.settings.allows_modifier:
							modified_forbidden.append("%s: %s" % [title, kind])
					if enemy.test_move(enemy.global_transform.translated(Vector3(0.0, 0.15, 0.0)), Vector3.ZERO, null, 0.001, true):
						_add(combat_problems, "%s: %s внутри геометрии" % [title, kind])
				for round_index: int in 12:
					if challenge.state == 3:
						break
					for enemy in challenge.director.enemies.duplicate():
						enemy.set_physics_process(false)
						enemy.take_hit(DamageInfo.create(1.0e9, false, enemy.global_position + Vector3(0, 1, 0)))
					await _secs(0.6)
				if challenge.state != 3 or not challenge.portal.is_open:
					_add(combat_problems, "%s: испытание не закончилось (состояние %d)" % [title, challenge.state])
				for door in challenge.doors:
					if door.is_closed:
						_add(combat_problems, "%s: дверь осталась закрытой" % title)
				challenges_run += 1
			# Магазин: постаменты заняты по настройкам.
			for shop in _builder.shops:
				var markers: int = shop.room.get_markers(&"shop_item").size()
				if shop.stock.size() != mini(_run_settings.shop_weapons + _run_settings.shop_medkits, markers):
					_add(combat_problems, "зона %d: на постаментах %d предметов вместо %d" % [zone_number, shop.stock.size(), mini(_run_settings.shop_weapons + _run_settings.shop_medkits, markers)])
			# Физический проход к самой дальней точке.
			if zones % WALK_EVERY == 1 and farthest_length > 0.0:
				var left: Vector3 = await Walker.walk(holder, map, start, farthest, WALK_SPEED)
				walks += 1
				jumps += int(left.z)
				walked_distance += farthest_length
				if left.x > 1.5 or left.y > 2.0:
					walk_problems.append("зона %d сид %d: осталось %.1f м по горизонтали, %.1f м по высоте из %.0f м" % [zone_number, seed_index, left.x, left.y, farthest_length])
	print("INFO  свип занял %.0f с, зона строится и ждёт навигацию в среднем %.1f с, дольше всех %.1f с" % [float(Time.get_ticks_msec() - started) / 1000.0, float(total_ms) / float(maxi(zones, 1)) / 1000.0, float(slowest_ms) / 1000.0])
	_check(nav_problems.is_empty(), "%d зон, %d стыков комнат друг над другом, %d точек комнат: от старта по навигации достижимы все %s" % [zones, joints, points, str(nav_problems)])
	_check(vertical_locked > 0 and vertical_open_in_fight == 0, "вертикальные стыки комнат с боем закрываются плитой на время боя: закрыто %d плит, непроходимых %d" % [vertical_locked, vertical_locked - vertical_open_in_fight])
	_check(combat_problems.is_empty() and rooms_fought > 0, "бой в %d комнатах: %d врагов (%s) стоят на свободной земле у сетки навигации, после гибели всех бой закончен и двери открыты %s" % [rooms_fought, enemies_spawned, str(enemy_kinds), str(combat_problems)])
	_check(modified_seen > 0 and modified_forbidden.is_empty(), "префиксы врагов (№92): среди %d врагов в боях и испытаниях у %d есть префикс, у элитных и боссов его нет %s" % [enemies_spawned, modified_seen, str(modified_forbidden)])
	_run_settings.wave_pause = _wave_pause_before
	_check(challenges_run > 0, "испытания пройдены в %d комнатах (шлюзы, эвакуация, босс): враги на местах, двери и портал открываются" % challenges_run)
	_check(walk_problems.is_empty() and walks > 0, "капсула игрока физически дошла до самой дальней комнаты в %d зонах (около %.0f м пути) %s" % [walks, walked_distance, str(walk_problems)])
	_check(jumps <= walks * 4, "на этих маршрутах понадобилось мало прыжков через ступеньки сетки навигации: %d на %d маршрутов" % [jumps, walks])
	print("=== FAILS: ", _fails)
	quit(_fails)


func _add(problems: Dictionary, message: String) -> void:
	problems[message] = int(problems.get(message, 0)) + 1


# Проверка достижимости всех точек всех комнат зоны от старта по сетке навигации.
func _reachability(layout: ZoneLayout, map: RID, start: Vector3) -> Dictionary:
	var problems: PackedStringArray = []
	var points: int = 0
	var farthest: Vector3 = start
	var farthest_length: float = 0.0
	for piece: PlacedPiece in layout.pieces:
		if piece.is_corridor():
			continue
		for point: Vector3 in _room_points(piece):
			points += 1
			var target: Vector3 = NavigationServer3D.map_get_closest_point(map, point)
			var path: PackedVector3Array = NavigationServer3D.map_get_path(map, start, target, true)
			if Vector2(target.x - point.x, target.z - point.z).length() > 1.5 or absf(target.y - point.y) > 1.8 or path.size() < 2 or path[path.size() - 1].distance_to(target) > 1.5:
				problems.append("%s (%d) точка %s: ближайшая сетка %s, путь из %d точек" % [piece.definition.resource_path.get_file(), piece.index, str(point), str(target), path.size()])
				continue
			var length: float = 0.0
			for i: int in range(1, path.size()):
				length += path[i].distance_to(path[i - 1])
			if length > farthest_length:
				farthest_length = length
				farthest = target
	return {"problems": problems, "points": points, "farthest": farthest, "length": farthest_length}


# Точки внутри комнаты, куда обязательно должен дойти игрок: входы изнутри и точки появления врагов и награды.
func _room_points(piece: PlacedPiece) -> Array[Vector3]:
	var result: Array[Vector3] = []
	var room: RoomPiece = _builder.pieces[piece.index]
	for entrance: RoomInfo.Entrance in piece.info.entrances:
		if not entrance.is_vertical():
			result.append(piece.transform * (entrance.position - entrance.direction * 1.5))
	for group: String in ["enemy_spawn", "loot_spawn", "exit_portal", "terminal", "boss_spawn", "elite_spawn"]:
		for marker: Marker3D in room.get_markers(group):
			result.append(marker.global_position)
	return result


func _wait_built() -> void:
	# Зона строится вместе с ожиданием карты навигации: в крупной зоне это тысячи кадров.
	for i: int in 20000:
		await process_frame
		if _scene.layout != null and not _scene._busy:
			break
	await _frames(5)


func _wait_navigation() -> void:
	var map: RID = root.get_world_3d().navigation_map
	for i: int in 400:
		await physics_frame
		if NavigationServer3D.map_get_regions(map).size() == 1 and NavigationServer3D.map_get_closest_point(map, Vector3(0.0, 0.5, 0.0)) != Vector3.ZERO:
			break
	await _frames(3)
