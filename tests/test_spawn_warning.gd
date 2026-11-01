@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Свечение места появления и пауза перед появлением врагов (№87). При входе в боевую комнату двери закрываются сразу, а враги
## появляются через spawn_warning_time: до этого они скрыты и неуязвимы, но уже считаются живыми (бой не кончается), на полу под каждым
## светится метка. Потом враги просыпаются, метки вспыхивают и пропадают. Погибший во сне враг убирает свою метку.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_spawn_warning.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.

var _fails: int = 0
var _scene: Node
var _builder
var _player
var _settings: ZoneSettings
var _run_settings: RunSettings


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _wait_built() -> void:
	for i: int in 20000:
		await process_frame
		if _scene.layout != null and not _scene._busy:
			break
	await _frames(5)


func _beacons(room: Node) -> Array:
	var result: Array = []
	for child: Node in room.get_children():
		if child.get_script() != null and child.get_script().get_global_name() == "SpawnBeacon":
			result.append(child)
	return result


func _combat_controller():
	for controller in _builder.controllers:
		if controller.kind == RoomDefinition.Kind.COMBAT:
			return controller
	return null


func _initialize() -> void:
	create_timer(600.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	var config = root.get_node("Config")
	_settings = config.data.zones
	_run_settings = config.data.run
	_settings.debug_seed = 4242
	root.size = Vector2i(1920, 1080)
	_scene = (load("res://run/run.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	_builder = _scene.get_node("Zone")
	_player = _scene.get_node("Player")
	_player.damaged.connect(func(_amount: float, _from: Vector3) -> void: _player.set_health(_player.max_health))
	await _wait_built()
	await _run()
	print("=== FAILS: ", _fails)
	quit(_fails)


func _run() -> void:
	var warning: float = _run_settings.spawn_warning_time
	print("--- Пауза и свечение перед появлением")
	_check(warning > 0.0, "в настройках забега задана пауза перед появлением: %.1f с" % warning)
	var controller = _combat_controller()
	_check(controller != null, "в зоне есть боевая комната")
	if controller == null:
		return
	var room: Node = controller.room
	controller.state = 1
	controller._start_combat()
	await _frames(3)
	var enemies: Array = controller.enemies.duplicate()
	_check(enemies.size() > 0 and controller.enemies_alive == enemies.size(), "бой начался: врагов %d, все считаются живыми" % enemies.size())
	var doors_closed: bool = not controller.doors.is_empty()
	for door in controller.doors:
		if not door.is_closed:
			doors_closed = false
	_check(doors_closed, "двери закрылись сразу при входе (%d)" % controller.doors.size())
	var all_dormant: bool = true
	for enemy in enemies:
		if not enemy.dormant or enemy.visible or enemy.collision_layer != 0 or enemy.is_physics_processing():
			all_dormant = false
	_check(all_dormant, "до появления все враги скрыты, не двигаются и не принимают попаданий")
	_check(_beacons(room).size() == enemies.size(), "под каждым врагом светится метка: %d" % _beacons(room).size())
	var lowest_gap: float = INF
	for beacon in _beacons(room):
		lowest_gap = minf(lowest_gap, absf(beacon.global_position.y - room.global_position.y))
	await _frames(int(warning * 120.0 * 0.5))
	var still_dormant: bool = true
	for enemy in enemies:
		if not enemy.dormant:
			still_dormant = false
	_check(still_dormant and _beacons(room).size() == enemies.size(), "на середине паузы враги всё ещё не появились, метки светятся")
	await _frames(int(warning * 120.0 * 0.5) + 20)
	var all_awake: bool = true
	for enemy in enemies:
		if enemy.dormant or not enemy.visible or enemy.collision_layer == 0 or not enemy.is_physics_processing():
			all_awake = false
	_check(all_awake, "по истечении паузы все враги появились: видимы, двигаются, принимают попадания")
	await _frames(60)
	_check(_beacons(room).is_empty(), "метки вспыхнули и погасли")
	for enemy in controller.enemies.duplicate():
		enemy.take_hit(DamageInfo.create(1.0e9, false, enemy.global_position + Vector3(0, 1, 0)))
	await _frames(10)
	_check(controller.state == 2, "бой закончился после гибели врагов")

	print("--- Гибель врага во сне и бой без паузы")
	controller = null
	for candidate in _builder.controllers:
		if candidate.kind == RoomDefinition.Kind.COMBAT and candidate.state == 0:
			controller = candidate
			break
	_check(controller != null, "нашлась вторая боевая комната")
	if controller != null:
		room = controller.room
		controller.state = 1
		controller._start_combat()
		await _frames(3)
		var sleepers: Array = controller.enemies.duplicate()
		var victim = sleepers[0]
		victim.take_hit(DamageInfo.create(1.0e9, false, victim.global_position + Vector3(0, 1, 0)))
		await _frames(3)
		_check(victim.is_dead and _beacons(room).size() == sleepers.size() - 1 and controller.enemies_alive == sleepers.size() - 1, "враг погиб, не успев появиться: его метка убрана, остальные ждут (метки %d)" % _beacons(room).size())
		for enemy in controller.enemies.duplicate():
			enemy.take_hit(DamageInfo.create(1.0e9, false, enemy.global_position + Vector3(0, 1, 0)))
		await _frames(10)
		_check(controller.state == 2 and _beacons(room).is_empty(), "бой окончен прямо в паузе: метки убраны")
	_run_settings.spawn_warning_time = 0.0
	controller = null
	for candidate in _builder.controllers:
		if candidate.kind == RoomDefinition.Kind.COMBAT and candidate.state == 0:
			controller = candidate
			break
	if controller != null:
		controller.state = 1
		controller._start_combat()
		await _frames(3)
		var instant: bool = not controller.enemies.is_empty()
		for enemy in controller.enemies:
			if enemy.dormant or not enemy.visible:
				instant = false
		_check(instant and _beacons(controller.room).is_empty(), "с паузой 0 враги появляются сразу, меток нет")
	else:
		_check(false, "нашлась третья боевая комната")
	_run_settings.spawn_warning_time = warning
