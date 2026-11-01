@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Укрытия для врагов (№93, основа механики). Данные, место за укрытием под положение игрока (скрыт от него, по бокам видно
## игрока), учёт занятости мест, поиск ближайшего скрытого места, укрытие держит пули, расстановка в боевых комнатах.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_cover.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.

const EYE: float = 1.65

var _fails: int = 0
var _props: PropSettings
var _world: Node3D
var _scatter_script


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _space() -> PhysicsDirectSpaceState3D:
	return _world.get_world_3d().direct_space_state


# Укрытие вида definition в точке, повёрнутое на yaw.
func _cover(definition: CoverDefinition, pos: Vector3, yaw: float = 0.0) -> CoverObject:
	var cover: CoverObject = CoverObject.create(definition, _props)
	_world.add_child(cover)
	cover.global_position = pos
	cover.rotation.y = yaw
	return cover


func _initialize() -> void:
	create_timer(300.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	_props = root.get_node("Config").data.props
	_scatter_script = load("res://run/props/prop_scatterer.gd")
	_world = Node3D.new()
	root.add_child(_world)
	# Пол из мира: слой 1, плита 80 x 80.
	var floor_body: StaticBody3D = StaticBody3D.new()
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(80.0, 1.0, 80.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	_world.add_child(floor_body)
	await _frames(2)
	await _run()
	print("=== FAILS: ", _fails)
	quit(_fails)


func _run() -> void:
	print("--- Данные")
	var data_ok: bool = _props.cover.size() >= 2 and _props.combat_cover_max >= _props.combat_cover_min and _props.combat_cover_max > 0
	for definition: CoverDefinition in _props.cover:
		data_ok = data_ok and definition.size.y >= 1.9 and definition.capacity >= 1 and definition.weight > 0.0
	_check(data_ok, "%d вида укрытий, высота не меньше 1.9 м (прячет врага целиком), мест не меньше одного, в боевой комнате %d-%d" % [_props.cover.size(), _props.combat_cover_min, _props.combat_cover_max])

	print("--- Место за укрытием")
	var wall_def: CoverDefinition = _props.cover[0]
	var wall: CoverObject = _cover(wall_def, Vector3.ZERO)
	await _frames(2)
	var half: Vector3 = wall_def.size * 0.5
	var threat: Vector3 = Vector3(0.0, 0.0, 12.0)
	var spot: CoverSpot = wall.get_spot(threat, 0)
	_check(spot.hide_position.z < -half.z and CoverFinder.is_hidden(_space(), threat, EYE, spot.hide_position), "игрок спереди: место за укрытием с противоположной стороны (z %.1f), игрока от него не видно" % spot.hide_position.z)
	var peek_ok: bool = spot.peek_positions.size() == 2
	for peek: Vector3 in spot.peek_positions:
		peek_ok = peek_ok and absf(peek.x) > half.x and CoverFinder.can_see(_space(), threat, EYE, peek)
	_check(peek_ok, "по бокам две точки выглядывания за краем укрытия, оттуда игрока видно")
	var behind_spot: CoverSpot = wall.get_spot(Vector3(0.0, 0.0, -12.0), 0)
	_check(behind_spot.hide_position.z > half.z and CoverFinder.is_hidden(_space(), Vector3(0.0, 0.0, -12.0), EYE, behind_spot.hide_position), "игрок с другой стороны: место переехало на противоположную")
	_check(not CoverFinder.is_hidden(_space(), threat, EYE, Vector3(0.0, 0.0, 6.0)), "на открытом месте перед укрытием враг не скрыт")
	var turned: CoverObject = _cover(wall_def, Vector3(30.0, 0.0, 0.0), PI * 0.5)
	await _frames(2)
	var turned_threat: Vector3 = Vector3(42.0, 0.0, 0.0)
	var turned_spot: CoverSpot = turned.get_spot(turned_threat, 0)
	_check(turned_spot.hide_position.x < 30.0 - half.z and CoverFinder.is_hidden(_space(), turned_threat, EYE, turned_spot.hide_position), "повёрнутое укрытие тоже прячет от игрока")
	turned.free()

	print("--- Места и поиск")
	var first: Node3D = Node3D.new()
	var second: Node3D = Node3D.new()
	var third: Node3D = Node3D.new()
	for holder: Node3D in [first, second, third]:
		_world.add_child(holder)
	var capacity: int = wall.get_capacity()
	var slots: Array[int] = []
	var distinct: bool = true
	for i: int in capacity:
		var holder: Node3D = [first, second, third][i % 3]
		var slot: int = wall.get_free_slot(holder)
		distinct = distinct and wall.claim(slot, holder) and not slots.has(slot)
		slots.append(slot)
		if i >= 2:
			break
	_check(distinct and wall.get_claim_count() == mini(capacity, 3), "каждый претендент занимает своё место (занято %d из %d)" % [wall.get_claim_count(), capacity])
	var extra: Node3D = Node3D.new()
	_world.add_child(extra)
	_check(capacity > 3 or (wall.get_free_slot(extra) == -1 and not wall.claim(0, extra)), "когда места кончились, новому претенденту отказ")
	wall.release(first)
	_check(not wall.is_claimed_by(first) and wall.get_free_slot(extra) >= 0, "освобождённое место снова свободно")
	for holder: Node3D in [first, second, third, extra]:
		wall.release(holder)
	_check(wall.get_claim_count() == 0, "после освобождения мест не занято ни одно")
	var near_cover: CoverObject = wall
	var far_cover: CoverObject = _cover(wall_def, Vector3(-25.0, 0.0, 0.0))
	await _frames(2)
	var hunter: Node3D = Node3D.new()
	_world.add_child(hunter)
	var found: CoverSpot = CoverFinder.find_best(self, Vector3(4.0, 0.0, 2.0), threat, hunter, 60.0)
	_check(found != null and found.cover == near_cover, "из двух укрытий берётся ближайшее к врагу")
	_check(CoverFinder.claim(found, hunter) and near_cover.is_claimed_by(hunter), "найденное место можно занять")
	_check(CoverFinder.find_best(self, Vector3(4.0, 0.0, 2.0), threat, hunter, 3.0) == null, "дальше предела поиска укрытия нет")
	far_cover.free()
	near_cover.release(hunter)
	await _frames(1)

	print("--- Укрытие держит пули")
	var shot: Dictionary = _space().intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(0.0, 1.0, 12.0), Vector3(0.0, 1.0, -12.0), 5))
	_check(not shot.is_empty() and shot["collider"] == wall, "луч выстрела упирается в укрытие (слой мира), а не проходит насквозь")
	wall.free()

	print("--- Расстановка в боевых комнатах")
	var catalog: Array[RoomDefinition] = RoomCatalog.load_all()
	var combat: Array[RoomDefinition] = []
	for definition: RoomDefinition in catalog:
		if definition.kind == RoomDefinition.Kind.COMBAT and combat.size() < 3:
			combat.append(definition)
	var total: int = 0
	var rooms_ok: bool = not combat.is_empty()
	var repeat_ok: bool = true
	var offset: float = 300.0
	for definition: RoomDefinition in combat:
		var room: RoomPiece = definition.scene.instantiate() as RoomPiece
		root.add_child(room)
		room.global_position = Vector3(offset, 0.0, 0.0)
		offset += 300.0
		await _frames(6)
		var holder: Node3D = Node3D.new()
		root.add_child(holder)
		var placed: int = _scatter_script.scatter_cover(room, _props, 777, holder)
		await _frames(2)
		total += placed
		rooms_ok = rooms_ok and placed <= _props.combat_cover_max and holder.get_child_count() == placed
		var entrances: Array[Vector3] = []
		for entrance: RoomEntrance in room.get_entrances():
			entrances.append(entrance.global_position)
		var spawns: Array[Vector3] = []
		for marker: Marker3D in room.get_markers(&"enemy_spawn"):
			spawns.append(marker.global_position)
		var positions: Array[Vector3] = []
		for cover: Node3D in holder.get_children():
			rooms_ok = rooms_ok and cover.is_in_group(&"cover") and cover.collision_layer == 1
			positions.append(cover.global_position)
			for entrance_position: Vector3 in entrances:
				rooms_ok = rooms_ok and Vector2(entrance_position.x - cover.global_position.x, entrance_position.z - cover.global_position.z).length() >= _props.entrance_clearance - 0.01
			for spawn_position: Vector3 in spawns:
				rooms_ok = rooms_ok and Vector2(spawn_position.x - cover.global_position.x, spawn_position.z - cover.global_position.z).length() >= _props.cover_spawn_clearance - 0.01
		# Повтор с тем же сидом: прежние укрытия сначала убираются, иначе они мешают новым местам.
		holder.free()
		await _frames(3)
		var again: Node3D = Node3D.new()
		root.add_child(again)
		var placed_again: int = _scatter_script.scatter_cover(room, _props, 777, again)
		repeat_ok = repeat_ok and placed_again == placed
		for i: int in mini(placed, again.get_child_count()):
			repeat_ok = repeat_ok and positions[i].distance_to(again.get_child(i).global_position) < 0.01
		again.free()
		room.free()
		await _frames(2)
	_check(rooms_ok and total > 0, "боевые комнаты: укрытий не больше %d на комнату, не у проёмов и не у мест появления врагов (всего %d в %d комнатах)" % [_props.combat_cover_max, total, combat.size()])
	_check(repeat_ok, "тот же сид даёт те же места")
	var disabled_copy: PropSettings = _props.duplicate()
	disabled_copy.enabled = false
	var off_room: RoomPiece = combat[0].scene.instantiate() as RoomPiece
	root.add_child(off_room)
	var off_holder: Node3D = Node3D.new()
	root.add_child(off_holder)
	_check(_scatter_script.scatter_cover(off_room, disabled_copy, 5, off_holder) == 0 and off_holder.get_child_count() == 0, "при enabled = false укрытий нет")
	off_holder.free()
	off_room.free()
