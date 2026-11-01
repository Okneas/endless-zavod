@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Воздух: камера и клавиши разворачивают полёт, но суммарная скорость не растёт (без бхопа).
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_air_control.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.

var _player
var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _heading() -> float:
	return rad_to_deg(atan2(_player.velocity.x, -_player.velocity.z))


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	var room: Node = (load("res://rooms/test_room.tscn") as PackedScene).instantiate()
	room.get_node("Enemies").free()
	root.add_child(room)
	await _frames(10)
	_player = room.get_node("Player")
	var m: MovementSettings = _player.movement

	# 1) Спринт, прыжок, поворот камеры на 90° вправо: траектория должна развернуться, скорость нет.
	_player.global_position = Vector3(0, 0.05, 18)
	await _frames(40)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(100)
	var speed0: float = _player.get_horizontal_speed()
	var heading0: float = _heading()
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	var max_speed: float = 0.0
	for tick: int in 60:
		await physics_frame
		if tick < 30:
			_player.rotate_y(deg_to_rad(-3.0))  # 90° вправо за 0.25 с
		max_speed = maxf(max_speed, _player.get_horizontal_speed())
	var heading1: float = _heading()
	print("курс до/после: ", snappedf(heading0, 0.1), " -> ", snappedf(heading1, 0.1), "; скорость до/макс: ", snappedf(speed0, 0.1), " / ", snappedf(max_speed, 0.1))
	_check(absf(heading1 - heading0) > 20.0, "в воздухе траектория разворачивается вслед за камерой (на %.0f°)" % absf(heading1 - heading0))
	_check(max_speed <= maxf(speed0, m.sprint_speed) * 1.01, "при этом скорость не растёт (макс %.2f при спринте %.1f)" % [max_speed, m.sprint_speed])

	# 2) Стоя на месте: прыжок и набор скорости в воздухе по-прежнему работает до потолка.
	Input.action_release("move_forward")
	Input.action_release("sprint")
	await _frames(120)
	_player.global_position = Vector3(0, 0.05, 18)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = 0.0
	await _frames(40)
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	Input.action_press("move_forward")
	var air_speed: float = 0.0
	for tick: int in 70:
		await physics_frame
		if not _player.is_on_floor():
			air_speed = maxf(air_speed, _player.get_horizontal_speed())
	_check(air_speed > 3.0 and air_speed <= m.walk_speed + 0.01, "прыжок с места: в воздухе можно набрать скорость до ходьбы (%.2f из %.1f)" % [air_speed, m.walk_speed])
	Input.action_release("move_forward")
	print("=== FAILS: ", _fails)
	quit(_fails)
