@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Рывок (срез 7б, №83): касание Shift даёт рывок, удержание остаётся спринтом, три заряда восстанавливаются по одному,
## рывок идёт по движению (без клавиш вперёд), работает в воздухе, на его время игрок неуязвим и снаряды пролетают сквозь него.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_dash.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.

var _fails: int = 0
var _room: Node
var _player


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _release_all() -> void:
	for a: String in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "hook", "sprint"]:
		Input.action_release(a)


func _place(pos: Vector3, yaw_deg: float = 0.0) -> void:
	_release_all()
	await _frames(3)
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.rotation.y = deg_to_rad(yaw_deg)
	_player.set_look_pitch(0.0)
	_player.dash_charges = _player.movement.dash_charges_max
	await _frames(40)


# Касание Shift: нажал и отпустил почти сразу.
func _tap_shift(ticks: int = 3) -> void:
	Input.action_press("sprint")
	await _frames(ticks)
	Input.action_release("sprint")
	await _frames(1)


func _initialize() -> void:
	create_timer(300.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	_room = (load("res://rooms/test_room.tscn") as PackedScene).instantiate()
	_room.get_node("Enemies").free()
	root.add_child(_room)
	_room.get_node("Dummies").queue_free()
	await _frames(10)
	_player = _room.get_node("Player")
	await _run()
	_release_all()
	print("=== FAILS: ", _fails)
	quit(_fails)


func _run() -> void:
	var m: MovementSettings = _player.movement
	var start: Vector3 = Vector3(0, 0.05, 18)

	print("--- Настройки")
	_check(m.dash_charges_max >= 1 and m.dash_speed > m.sprint_speed and m.dash_duration > 0.0 and m.dash_recharge_time > 0.0 and m.dash_tap_time > 0.0, "в настройках рывка есть заряды (%d), скорость %.1f м/с, длительность %.2f с, восстановление %.1f с" % [m.dash_charges_max, m.dash_speed, m.dash_duration, m.dash_recharge_time])
	_check(InputMap.has_action("sprint") and not InputMap.has_action("dash"), "отдельного действия рывка нет: он берётся из касания sprint (Shift)")
	await _place(start)
	_check(_player.dash_charges == m.dash_charges_max, "игрок начинает с полными зарядами (%d)" % _player.dash_charges)

	print("--- Касание и удержание")
	var before: Vector3 = _player.global_position
	await _tap_shift()
	await _frames(1)
	_check(_player.is_dashing() and _player.get_state_key() == "DASH", "касание Shift запускает рывок (ключ состояния DASH)")
	_check(_player.dash_charges == m.dash_charges_max - 1, "заряд потрачен: %d из %d" % [_player.dash_charges, m.dash_charges_max])
	await _frames(int(m.dash_duration * 120.0) + 6)
	var moved: float = (_player.global_position - before).length()
	var expected: float = m.dash_speed * m.dash_duration
	_check(moved > expected * 0.7 and moved < expected * 1.6, "рывок без клавиш идёт вперёд по взгляду на %.1f м (ждём около %.1f)" % [moved, expected])
	_check(_player.global_position.z < before.z - expected * 0.5 and absf(_player.global_position.x - before.x) < 0.3, "направление вперёд (-Z), вбок не сносит")
	_check(not _player.is_dashing() and _player.get_state_key() != "DASH", "рывок закончился")
	await _place(start)
	Input.action_press("sprint")
	Input.action_press("move_forward")
	await _frames(int(m.dash_tap_time * 120.0) + 40)
	_check(not _player.is_dashing() and _player.dash_charges == m.dash_charges_max, "удержание Shift рывка не даёт и заряды целы")
	_check(absf(_player.get_horizontal_speed() - m.sprint_speed) < 0.3, "удержание остаётся спринтом: %.2f м/с" % _player.get_horizontal_speed())
	Input.action_release("sprint")
	await _frames(20)
	_check(not _player.is_dashing() and _player.dash_charges == m.dash_charges_max, "отпускание после долгого удержания рывка не запускает")

	print("--- Направление по движению")
	await _place(start)
	Input.action_press("move_left")
	await _frames(2)
	before = _player.global_position
	await _tap_shift()
	await _frames(int(m.dash_duration * 120.0) + 6)
	_check(_player.global_position.x < before.x - m.dash_speed * m.dash_duration * 0.5 and absf(_player.global_position.z - before.z) < 0.5, "с A рывок уходит влево, а не вперёд (x %.1f -> %.1f)" % [before.x, _player.global_position.x])
	await _place(Vector3(0, 0.05, 0))
	Input.action_press("move_back")
	await _frames(2)
	before = _player.global_position
	await _tap_shift()
	await _frames(int(m.dash_duration * 120.0) + 6)
	_check(_player.global_position.z > before.z + m.dash_speed * m.dash_duration * 0.5, "с S рывок идёт назад (z %.1f -> %.1f)" % [before.z, _player.global_position.z])

	print("--- Заряды: три рывка, потом пусто, восстановление по одному")
	await _place(start)
	var done: int = 0
	for i: int in m.dash_charges_max:
		await _tap_shift()
		await _frames(int(m.dash_duration * 120.0) + 4)
		done += 1
	_check(done == m.dash_charges_max and _player.dash_charges == 0, "после %d рывков зарядов 0" % done)
	var dashes_before: Vector3 = _player.global_position
	await _tap_shift()
	await _frames(int(m.dash_duration * 120.0) + 4)
	_check(not _player.is_dashing() and (_player.global_position - dashes_before).length() < 0.5, "без зарядов рывка нет")
	var progress_early: float = _player.get_dash_recharge_progress()
	await _frames(int((m.dash_recharge_time * 0.5) * 120.0))
	var progress_mid: float = _player.get_dash_recharge_progress()
	_check(progress_mid > progress_early and progress_mid < 1.0 and _player.dash_charges == 0, "заряд накапливается (%.2f -> %.2f), пока не готов" % [progress_early, progress_mid])
	await _frames(int((m.dash_recharge_time * 0.5) * 120.0) + 20)
	_check(_player.dash_charges == 1, "через время восстановления вернулся один заряд (%d)" % _player.dash_charges)
	await _frames(int(m.dash_recharge_time * 120.0) + 20)
	_check(_player.dash_charges == 2, "потом ещё один: заряды идут по очереди (%d)" % _player.dash_charges)
	await _frames(int(m.dash_recharge_time * 120.0) * 2)
	_check(_player.dash_charges == m.dash_charges_max, "в итоге снова полные заряды (%d)" % _player.dash_charges)

	print("--- Рывок в воздухе")
	await _place(start)
	_player.global_position = Vector3(0, 8.0, 18)
	_player.velocity = Vector3.ZERO
	await _frames(6)
	var y_before: float = _player.global_position.y
	before = _player.global_position
	Input.action_press("move_forward")
	await _tap_shift()
	await _frames(int(m.dash_duration * 120.0 * 0.5))
	_check(_player.is_dashing() and absf(_player.global_position.y - y_before) < 0.6, "в воздухе рывок идёт ровно: высота почти не падает (%.2f -> %.2f)" % [y_before, _player.global_position.y])
	await _frames(int(m.dash_duration * 120.0) + 6)
	_check((_player.global_position - before).length() > m.dash_speed * m.dash_duration * 0.6, "воздушный рывок прошёл расстояние %.1f м" % (_player.global_position - before).length())
	Input.action_release("move_forward")

	print("--- Неуязвимость")
	await _place(start)
	var health_before: int = _player.health
	await _tap_shift()
	await _frames(2)
	_check(_player.is_dashing() and _player.is_invulnerable(), "в начале рывка игрок неуязвим")
	_player.take_damage(30.0)
	_check(_player.health == health_before, "урон в рывке не проходит (здоровье %d)" % _player.health)
	var projectile = load("res://enemies/enemy_projectile.gd").spawn(_room, _player.global_position + Vector3(0, 1.0, 3.0), Vector3(0, 0, -20.0), 30.0, 3.0)
	await _frames(int(m.dash_invulnerability * 120.0 * 0.5))
	_check(_player.health == health_before and is_instance_valid(projectile) and not projectile.is_queued_for_deletion(), "снаряд, летящий в игрока в рывке, пролетает сквозь него")
	if is_instance_valid(projectile):
		projectile.queue_free()
	await _frames(int(m.dash_invulnerability * 120.0) + int(m.dash_duration * 120.0) + 10)
	_check(not _player.is_invulnerable(), "после рывка неуязвимость кончилась")
	_player.take_damage(30.0)
	_check(_player.health == health_before - 30, "после рывка урон проходит (здоровье %d)" % _player.health)

	print("--- Смерть и воскрешение")
	await _place(start)
	_player.dash_charges = 0
	_player.respawn(start, 0.0)
	_check(_player.dash_charges == m.dash_charges_max and not _player.is_dashing(), "после воскрешения заряды полные")
