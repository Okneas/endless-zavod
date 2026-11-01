@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Автоогонь (режим automatic в данных корпуса) и автоперезарядка на пустом магазине.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_auto_fire.gd
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
	var player = room.get_node("Player")
	var weapon = player.get_weapon()
	player.global_position = Vector3(0, 0.05, 12)
	player.set_look_pitch(deg_to_rad(8.0))
	for i: int in 40:
		await physics_frame
	var counter: Dictionary = {"shots": 0}
	weapon.fired.connect(func(_r: float) -> void: counter["shots"] += 1)
	# Автоогонь: за 1.0 с должно получиться столько выстрелов, сколько даёт темп (магазин должен вместить).
	weapon.stats.automatic = true
	Input.action_press("fire")
	for i: int in 120:
		await physics_frame
	Input.action_release("fire")
	var rate: float = weapon.stats.fire_rate
	var capacity: int = weapon.stats.magazine_size
	_check(absf(counter["shots"] - rate) <= 1.0, "автоогонь: за 1 с выстрелов %d (темп %.1f/с)" % [counter["shots"], rate])
	_check(weapon.ammo == capacity - counter["shots"], "патроны списываются: %d из %d" % [weapon.ammo, capacity])
	# Опустошаем магазин удержанием: на пустом должна запуститься автоперезарядка без лишнего выстрела.
	for i: int in 60:
		await physics_frame
	weapon.ammo = capacity
	counter["shots"] = 0
	Input.action_press("fire")
	# Предел кадров от темпа и размера магазина (с запасом), а не постоянный: правки чисел оружия в Inspector не должны ронять проверку.
	for i: int in int(float(capacity) / rate * 120.0) + 120:
		await physics_frame
		if weapon.is_reloading:
			break
	Input.action_release("fire")
	_check(weapon.is_reloading and counter["shots"] == capacity, "удержание до конца магазина: ровно %d выстрелов, затем автоперезарядка" % capacity)
	print("=== FAILS: ", _fails)
	quit(_fails)
