extends SceneTree
## ТЕСТ: генерация зоны (срез 6): пул комнат, формулы зоны, ветвящийся рост (связность, стыковка входов, отсутствие
## пересечений, вертикальность, типы комнат, повторяемость по сиду). Сцены зоны не строятся, проверяется только логика.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_generation.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.

const SEEDS: int = 25

var _fails: int = 0
var _settings: ZoneSettings
var _catalog: Array[RoomDefinition]


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _initialize() -> void:
	_settings = load("res://data/content/balance/zone_settings.tres")
	_catalog = RoomCatalog.load_all()
	_test_catalog()
	_test_math()
	_test_layouts()
	_test_repeatability()
	print("=== FAILS: ", _fails)
	quit(_fails)


# --- Пул комнат.
func _test_catalog() -> void:
	print("--- Пул комнат и сцены")
	var by_kind: Dictionary = {}
	var problems: PackedStringArray = []
	for definition: RoomDefinition in _catalog:
		by_kind[definition.kind] = int(by_kind.get(definition.kind, 0)) + 1
		var info: RoomInfo = RoomCatalog.info_of(definition)
		if info.problem != "":
			problems.append("%s: %s" % [definition.resource_path, info.problem])
			continue
		for entrance: RoomInfo.Entrance in info.entrances:
			var box: AABB = info.bounds
			if entrance.is_vertical():
				# Проём в потолке или в полу: маркер на внешней плоскости плиты (верх габаритов или низ) и внутри них по горизонтали.
				var face: float = box.end.y if entrance.direction.y > 0.0 else box.position.y
				var flat: Vector3 = Vector3(entrance.position.x, box.get_center().y, entrance.position.z)
				if absf(entrance.position.y - face) > 0.05 or not box.grow(0.05).has_point(flat):
					problems.append("%s: вертикальный вход %s не на плоскости плиты габаритов %s" % [definition.resource_path, str(entrance.position), str(box)])
				if entrance.size.x <= entrance.size.y:
					problems.append("%s: проём стыка %s" % [definition.resource_path, str(entrance.size)])
				continue
			if not entrance.size.is_equal_approx(Vector2(4.0, 4.0)):
				problems.append("%s: проём %s" % [definition.resource_path, str(entrance.size)])
			# Вход лежит на грани габаритов: сцены стыкуются по плоскостям входов.
			var on_face: bool = false
			for axis: int in [0, 2]:
				var low: float = box.position[axis]
				var high: float = box.end[axis]
				if absf(entrance.position[axis] - low) < 0.05 or absf(entrance.position[axis] - high) < 0.05:
					on_face = true
			if not on_face or not box.grow(0.05).has_point(entrance.position):
				problems.append("%s: вход %s не на грани габаритов %s" % [definition.resource_path, str(entrance.position), str(box)])
	_check(problems.is_empty(), "%d сцен в пуле читаются: горизонтальные входы по осям, проёмы 4 x 4, на гранях габаритов, вертикальные проёмы стыков на плоскостях плит %s" % [_catalog.size(), str(problems)])
	_check(by_kind.get(RoomDefinition.Kind.START, 0) >= 1 and by_kind.get(RoomDefinition.Kind.COMBAT, 0) >= 3 and by_kind.get(RoomDefinition.Kind.LOOT, 0) >= 2 and by_kind.get(RoomDefinition.Kind.SHOP, 0) >= 1 and by_kind.get(RoomDefinition.Kind.BOSS, 0) >= 1 and by_kind.get(RoomDefinition.Kind.EVACUATION, 0) >= 1 and by_kind.get(RoomDefinition.Kind.CORRIDOR, 0) >= 4, "в пуле есть все типы, у боевых несколько вариантов: %s" % str(by_kind))
	var rise: bool = false
	for definition: RoomDefinition in _catalog:
		if definition.kind == RoomDefinition.Kind.CORRIDOR:
			var info: RoomInfo = RoomCatalog.info_of(definition)
			if info.entrances.size() == 2 and absf(info.entrances[0].position.y - info.entrances[1].position.y) > 1.0:
				rise = true
	_check(rise, "среди переходов есть пандусы между входами на разной высоте")
	var ups: int = 0
	var downs: int = 0
	for definition: RoomDefinition in _catalog:
		for entrance: RoomInfo.Entrance in RoomCatalog.info_of(definition).entrances:
			if entrance.is_vertical():
				if entrance.direction.y > 0.0:
					ups += 1
				else:
					downs += 1
	_check(ups >= 2 and downs >= 3 and _settings.vertical_link != null, "в пуле есть проёмы в потолке (%d) и в полу (%d) и лестница стыка в настройках зоны" % [ups, downs])


# --- Формулы.
func _test_math() -> void:
	print("--- Формулы зоны")
	var s: ZoneSettings = _settings
	# Уровень зоны (№85): кривая от 1 до потолка (уровня мира) за отдел, прирост между зонами не одинаков, потолок растягивает кривую.
	var curve_ok: bool = true
	var curve_text: PackedStringArray = []
	for cap: int in [s.world_level_start, s.world_level_start * 2, s.world_level_start * 3]:
		var levels: Array[int] = []
		for zone_number: int in range(1, s.zones_in_department + 1):
			levels.append(ZoneMath.zone_level(s, cap, zone_number))
		if cap == s.world_level_start:
			curve_text.append(str(levels))
		var increments: Array[int] = []
		for i: int in range(1, levels.size()):
			increments.append(levels[i] - levels[i - 1])
			if levels[i] < levels[i - 1]:
				curve_ok = false
		if levels[0] != 1 or levels[levels.size() - 1] != cap or ZoneMath.zone_level(s, cap, s.zones_in_department + 5) != cap:
			curve_ok = false
		# Не линейная: приросты не все равны, а при степени больше 1 последний прирост больше первого.
		var all_equal: bool = true
		for value: int in increments:
			if value != increments[0]:
				all_equal = false
		if all_equal or (s.level_curve_exponent > 1.0 and increments[increments.size() - 1] <= increments[0]):
			curve_ok = false
	_check(curve_ok, "уровень зоны: от 1 до потолка уровня мира, не убывает, прирост не одинаков (при потолке %d: %s)" % [s.world_level_start, " ".join(curve_text)])
	_check(ZoneMath.zone_level(s, 1, 5) == 1 and ZoneMath.zone_level(s, 0, 5) == 1, "при уровне мира 1 все зоны первого уровня")
	var rooms_ok: bool = true
	var previous: int = 0
	for zone_number: int in range(1, s.zones_in_department + 1):
		var count: int = ZoneMath.room_count(s, zone_number)
		if count < previous or count < 2 or count > s.rooms_max:
			rooms_ok = false
		previous = count
	_check(rooms_ok and ZoneMath.room_count(s, s.zones_in_department) >= ZoneMath.room_count(s, 1), "число комнат не убывает с номером зоны (%d в первой, %d в последней) и не выходит за пределы" % [ZoneMath.room_count(s, 1), ZoneMath.room_count(s, s.zones_in_department)])
	_check(ZoneMath.has_boss(s, s.zones_in_department) and not ZoneMath.has_boss(s, 1) and ZoneMath.enemy_count(s, 1) >= 1 and ZoneMath.enemy_count(s, s.zones_in_department) >= ZoneMath.enemy_count(s, 1), "босс только в последней зоне, врагов в комнате растёт с зоной")
	# Эвакуация (№86): в зонах, кратных evacuation_every (3, 6, 9), и никогда в зоне с боссом.
	var evac_zones: Array[int] = []
	var evac_rule_ok: bool = true
	for zone_number: int in range(1, s.zones_in_department + 1):
		var has: bool = ZoneMath.has_evacuation(s, zone_number)
		if has:
			evac_zones.append(zone_number)
		if has != (zone_number % s.evacuation_every == 0 and not ZoneMath.has_boss(s, zone_number)):
			evac_rule_ok = false
	_check(evac_rule_ok and not evac_zones.is_empty() and not ZoneMath.has_evacuation(s, s.zones_in_department), "комната эвакуации в каждой %d-й зоне и не в зоне с боссом: %s" % [s.evacuation_every, str(evac_zones)])


# --- Сгенерированные зоны.
func _test_layouts() -> void:
	print("--- Сгенерированные зоны")
	var s: ZoneSettings = _settings
	var generator: ZoneGenerator = ZoneGenerator.new()
	var problems: Dictionary = {}
	var total: int = 0
	var vertical: int = 0
	var with_joint: int = 0
	var joints: int = 0
	var boss_depth_ratio: float = 0.0
	var boss_count: int = 0
	var ms: float = 0.0
	var room_totals: Dictionary = {}
	for zone_number: int in range(1, s.zones_in_department + 1):
		for seed_value: int in SEEDS:
			var started: int = Time.get_ticks_usec()
			var layout: ZoneLayout = generator.generate(_catalog, s, zone_number, 1000 + seed_value, seed_value * 7919 + zone_number, s.world_level_start)
			ms += float(Time.get_ticks_usec() - started) / 1000.0
			total += 1
			room_totals[zone_number] = int(room_totals.get(zone_number, 0)) + layout.room_count()
			for message: String in _validate(layout, s):
				problems[message] = int(problems.get(message, 0)) + 1
			var box: AABB = layout.get_bounds()
			if box.size.y >= 6.0:
				vertical += 1
			var layout_joints: int = _count_vertical_joints(layout)
			joints += layout_joints
			if layout_joints > 0:
				with_joint += 1
			if layout.count(RoomDefinition.Kind.BOSS) == 1:
				var deepest: int = 0
				var boss: PlacedPiece
				for piece: PlacedPiece in layout.pieces:
					if not piece.is_corridor():
						deepest = maxi(deepest, piece.depth)
						if piece.kind() == RoomDefinition.Kind.BOSS:
							boss = piece
				boss_depth_ratio += float(boss.depth) / float(maxi(deepest, 1))
				boss_count += 1
	_check(problems.is_empty(), "%d зон (зоны 1-%d, %d сидов): число и типы комнат, связность, стыковка входов, без пересечений %s" % [total, s.zones_in_department, SEEDS, str(problems)])
	# Ожидаемая доля зависит от шанса в настройках: она не должна быть сильно ниже самого шанса.
	var expected_share: float = minf(0.7, _settings.vertical_chance * 1.5)
	_check(float(with_joint) / float(total) >= expected_share, "комнаты стоят друг над другом: вертикальные стыки есть на %d из %d зон (в среднем %.1f в зону, шанс в настройках %.2f)" % [with_joint, total, float(joints) / float(total), _settings.vertical_chance])
	_check(float(vertical) / float(total) > 0.6, "зоны вертикальные: перепад высот 6 м и больше у %d из %d" % [vertical, total])
	_check(boss_count > 0 and boss_depth_ratio / float(boss_count) > 0.85, "босс в самых глубоких ветках: средняя глубина %.2f от наибольшей" % (boss_depth_ratio / float(maxi(boss_count, 1))))
	_check(float(room_totals[s.zones_in_department]) > float(room_totals[1]), "комнат в последней зоне больше, чем в первой (%.1f против %.1f)" % [float(room_totals[s.zones_in_department]) / SEEDS, float(room_totals[1]) / SEEDS])
	print("INFO  генерация: в среднем %.1f мс в зону" % (ms / float(total)))


# Вход части other, которым она соединена с частью index (-1, если связи нет).
func _entrance_to(other: PlacedPiece, index: int) -> int:
	for entrance: int in other.links:
		if other.links[entrance] == index:
			return entrance
	return -1


# Сколько в зоне стыков, где одна комната стоит над другой.
func _count_vertical_joints(layout: ZoneLayout) -> int:
	var total: int = 0
	for piece: PlacedPiece in layout.pieces:
		for entrance: int in piece.links:
			if piece.info.entrances[entrance].is_vertical() and piece.info.entrances[entrance].direction.y > 0.0:
				total += 1
	return total


# Список нарушений в зоне (пустой, если всё верно).
func _validate(layout: ZoneLayout, s: ZoneSettings) -> Array[String]:
	var errors: Array[String] = []
	if not layout.warnings.is_empty():
		errors.append("замечания генератора: " + layout.warnings[0])
	var expected_rooms: int = ZoneMath.room_count(s, layout.zone_number)
	if layout.room_count() != expected_rooms:
		errors.append("число комнат не совпало с формулой")
	if layout.count(RoomDefinition.Kind.START) != 1 or layout.pieces[0].kind() != RoomDefinition.Kind.START:
		errors.append("стартовая комната не одна или не первая")
	if layout.count(RoomDefinition.Kind.BOSS) != (1 if ZoneMath.has_boss(s, layout.zone_number) else 0):
		errors.append("босс не по правилу")
	if layout.count(RoomDefinition.Kind.GATE) != (1 if ZoneMath.has_gate(s, layout.zone_number) else 0):
		errors.append("шлюз не по правилу")
	if layout.count(RoomDefinition.Kind.EVACUATION) != (1 if ZoneMath.has_evacuation(s, layout.zone_number) else 0):
		errors.append("эвакуация не по правилу")
	if layout.count(RoomDefinition.Kind.SHOP) > 1:
		errors.append("больше одного магазина")
	# Кладовая хотя бы одна, если хватает бюджета: стартовая, один бой и особые комнаты (магазин, эвакуация, босс, шлюз) идут вперёд неё.
	var special_rooms: int = layout.count(RoomDefinition.Kind.SHOP) + layout.count(RoomDefinition.Kind.EVACUATION) + layout.count(RoomDefinition.Kind.BOSS) + layout.count(RoomDefinition.Kind.GATE)
	var loot_budget: int = maxi(expected_rooms - 1 - special_rooms - 1, 0)
	if layout.count(RoomDefinition.Kind.LOOT) < mini(mini(ZoneMath.loot_room_count(s, layout.zone_number), 1), loot_budget):
		errors.append("нет кладовой")
	if layout.zone_level != ZoneMath.zone_level(s, s.world_level_start, layout.zone_number):
		errors.append("уровень зоны не по формуле")
	# Связность: обход от стартовой по связям должен дойти до всех.
	var reached: Dictionary = {0: true}
	var queue: Array[int] = [0]
	while not queue.is_empty():
		var current: PlacedPiece = layout.pieces[queue.pop_back()]
		for entrance: int in current.links:
			var neighbour: int = current.links[entrance]
			if not reached.has(neighbour):
				reached[neighbour] = true
				queue.append(neighbour)
	if reached.size() != layout.pieces.size():
		errors.append("зона несвязна")
	# Стыковка: входы пары совпадают по месту, смотрят друг на друга и одного размера; комнаты и переходы чередуются.
	for piece: PlacedPiece in layout.pieces:
		if piece.is_corridor() and piece.links.size() != 2:
			errors.append("у перехода не два соседа")
		for entrance: int in piece.links:
			var other: PlacedPiece = layout.pieces[piece.links[entrance]]
			var vertical_link: bool = piece.info.entrances[entrance].is_vertical()
			if other.is_corridor() == piece.is_corridor() and not vertical_link:
				errors.append("комнаты или переходы стоят вплотную друг к другу")
			if vertical_link:
				var other_entrance: int = _entrance_to(other, piece.index)
				if other.is_corridor() or piece.is_corridor():
					errors.append("вертикальный стык с переходом")
				elif other_entrance < 0 or absf(other.entrance_direction(other_entrance).y + piece.entrance_direction(entrance).y) > 0.01:
					errors.append("вертикальные входы пары смотрят в одну сторону")
				elif not other.entrance_footprint(other_entrance).is_equal_approx(piece.entrance_footprint(entrance)):
					errors.append("проёмы вертикального стыка разного размера")
			var back: int = -1
			for other_entrance: int in other.links:
				if other.links[other_entrance] == piece.index and other.entrance_position(other_entrance).distance_to(piece.entrance_position(entrance)) < 0.05:
					back = other_entrance
			if back < 0:
				errors.append("входы пары не совпали по месту")
			elif other.entrance_direction(back).distance_to(-piece.entrance_direction(entrance)) > 0.01 or not other.info.entrances[back].size.is_equal_approx(piece.info.entrances[entrance].size):
				errors.append("входы пары не смотрят друг на друга")
	# Без пересечений (с допуском: части стыкуются плоскостями).
	for i: int in layout.pieces.size():
		for j: int in range(i + 1, layout.pieces.size()):
			var a: AABB = layout.pieces[i].world_bounds().grow(-s.overlap_margin)
			var b: AABB = layout.pieces[j].world_bounds().grow(-s.overlap_margin)
			if a.intersects(b):
				errors.append("габариты пересекаются")
	return errors


# --- Повторяемость.
func _test_repeatability() -> void:
	print("--- Сид")
	var generator: ZoneGenerator = ZoneGenerator.new()
	var first: ZoneLayout = generator.generate(_catalog, _settings, 6, 11, 12345, _settings.world_level_start)
	var second: ZoneLayout = ZoneGenerator.new().generate(_catalog, _settings, 6, 11, 12345, _settings.world_level_start)
	var same: bool = first.pieces.size() == second.pieces.size()
	for i: int in mini(first.pieces.size(), second.pieces.size()):
		if first.pieces[i].definition != second.pieces[i].definition or not first.pieces[i].transform.is_equal_approx(second.pieces[i].transform):
			same = false
	_check(same, "один сид и номер зоны дают одну и ту же зону (%s)" % first.describe())
	var different: int = 0
	for seed_value: int in 20:
		var other: ZoneLayout = generator.generate(_catalog, _settings, 6, 11, 5000 + seed_value, _settings.world_level_start)
		if other.pieces.size() != first.pieces.size() or not other.pieces[other.pieces.size() - 1].transform.is_equal_approx(first.pieces[first.pieces.size() - 1].transform):
			different += 1
	_check(different >= 18, "разные сиды дают разные зоны (%d из 20)" % different)
