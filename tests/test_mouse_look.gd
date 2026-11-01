@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Взгляд мышью, зум и чувствительность, Esc (меню паузы) и захват мыши, независимость от размера окна. НУЖНО ОКНО (в headless захват мыши не работает):
## godot --path <проект> --fixed-fps 120 --resolution 320x200 --position -3000,-3000 --script res://tests/test_mouse_look.gd
## Пока идёт тест, физическую мышь не двигать: захваченная мышь принимает её движения и сбивает числа.
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.

var _fails: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _motion(rel: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.relative = rel
	ev.position = Vector2(100, 100)
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


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
	var player: Node = room.get_node("Player")
	var head: Node3D = player.get_node("Head")
	var sens: float = player.settings.mouse_sensitivity
	print("режим мыши после старта: ", Input.mouse_mode, " (CAPTURED=", Input.MOUSE_MODE_CAPTURED, ")")
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "мышь захвачена при старте")
	var stretch: float = root.get_final_transform().get_scale().x
	_check(stretch < 0.5, "окно 320 x 200 растянуто от эталона 1920 x 1080 (масштаб %.2f): чувствительность проверяется при растяжении" % stretch)

	var yaw0: float = player.rotation.y
	var pitch0: float = head.rotation.x
	_motion(Vector2(100, 50))
	await physics_frame
	_check(is_equal_approx(player.rotation.y, yaw0 - 100.0 * sens), "движение мыши вправо на 100 px поворачивает корпус на %.3f рад (yaw %.4f)" % [100.0 * sens, player.rotation.y - yaw0])
	_check(is_equal_approx(head.rotation.x, pitch0 - 50.0 * sens), "движение вниз на 50 px наклоняет взгляд вниз (pitch %.4f)" % head.rotation.x)
	_motion(Vector2(0, -100000))
	await physics_frame
	_check(is_equal_approx(head.rotation.x, deg_to_rad(89.0)), "взгляд вверх упирается в 89° (pitch %.1f°)" % rad_to_deg(head.rotation.x))
	_motion(Vector2(0, 100000))
	await physics_frame
	_check(is_equal_approx(head.rotation.x, -deg_to_rad(89.0)), "взгляд вниз упирается в -89° (pitch %.1f°)" % rad_to_deg(head.rotation.x))

	var esc := InputEventKey.new()
	esc.physical_keycode = KEY_ESCAPE
	esc.keycode = KEY_ESCAPE
	esc.pressed = true
	Input.parse_input_event(esc)
	Input.flush_buffered_events()
	await physics_frame
	_check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and paused, "Esc открывает паузу: мышь свободна (режим %d), игра на паузе" % Input.mouse_mode)
	var yaw1: float = player.rotation.y
	_motion(Vector2(300, 0))
	await physics_frame
	_check(is_equal_approx(player.rotation.y, yaw1), "при открытой паузе взгляд не вращается")
	Input.parse_input_event(esc)
	Input.flush_buffered_events()
	await physics_frame
	_check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not paused, "второй Esc закрывает паузу и возвращает захват мыши (режим %d)" % Input.mouse_mode)
	# Чувствительность под зум: при полном прицеливании мышь поворачивает камеру медленнее в zoom раз.
	Input.action_press("aim")
	for i: int in 40:
		await physics_frame
	var zoom: float = player.get_weapon().get_zoom()
	var yaw2: float = player.rotation.y
	_motion(Vector2(100, 0))
	await physics_frame
	var turned: float = yaw2 - player.rotation.y
	_check(zoom >= 1.0 and absf(turned - 100.0 * sens / zoom) < 0.0005, "при зуме x%.2f мышь 100 px поворачивает на %.4f рад (без зума было бы %.4f, ждём %.4f)" % [zoom, turned, 100.0 * sens, 100.0 * sens / zoom])
	Input.action_release("aim")
	for i: int in 40:
		await physics_frame
	var yaw3: float = player.rotation.y
	_motion(Vector2(100, 0))
	await physics_frame
	_check(absf((yaw3 - player.rotation.y) - 100.0 * sens) < 0.0005, "после выхода из прицеливания чувствительность прежняя")
	print("=== FAILS: ", _fails)
	quit(_fails)
