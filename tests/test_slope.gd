@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Склон 15 градусов: игрок поднимается, не теряет пол и скорость.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_slope.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	var room: Node = (load("res://rooms/test_room.tscn") as PackedScene).instantiate()
	room.get_node("Enemies").free()
	root.add_child(room)
	for i: int in 10:
		await physics_frame
	var player: CharacterBody3D = room.get_node("Player")
	# Низкий конец склона у севера (z=-6), высокий у юга (z=+6): идём с севера на юг (yaw 180).
	player.global_position = Vector3(8, 0.05, -10)
	player.rotation.y = deg_to_rad(180.0)
	for i: int in 40:
		await physics_frame
	Input.action_press("move_forward")
	var max_y: float = 0.0
	var off_floor_frames: int = 0
	var min_speed: float = 99.0
	for i: int in 150:
		await physics_frame
		max_y = maxf(max_y, player.global_position.y)
		if i > 60 and not player.is_on_floor():
			off_floor_frames += 1
		if i > 70:
			min_speed = minf(min_speed, Vector2(player.velocity.x, player.velocity.z).length())
	print("высота y макс=", snappedf(max_y, 0.01), ", z=", snappedf(player.global_position.z, 0.01), ", кадров без пола=", off_floor_frames, ", мин. скорость на склоне=", snappedf(min_speed, 0.01))
	var expected_y: float = (player.global_position.z + 5.96) * tan(deg_to_rad(15.0))
	_check(absf(max_y - expected_y) < 0.1 and max_y > 0.5, "высота совпадает с уклоном 15°: y=%.2f, ждём %.2f" % [max_y, expected_y])
	_check(off_floor_frames < 6, "на склоне пол не теряется (кадров без пола: %d из ~90)" % off_floor_frames)
	_check(min_speed > 5.5, "на склоне скорость не проваливается (мин %.2f м/с)" % min_speed)
	Input.action_release("move_forward")
	print("=== FAILS: ", _fails)
	quit(_fails)
