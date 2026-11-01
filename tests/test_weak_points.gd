@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Слабые места врагов (№93). У каждого типа есть шар слабого места с меткой, он поворачивается и растёт вместе с врагом, выстрел
## в него бьёт с множителем из данных (всегда как крит), мимо него обычно, у типов центр лежит у поверхности тела: луч выстрела
## спереди попадает в слабое место.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_weak_points.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.

const TYPES: Array[String] = ["chaser", "gunner", "flyer", "fly_shooter", "turret", "beam_turret", "bomber", "support", "warden", "elite", "boss"]
const ENEMY_POS: Vector3 = Vector3(0.0, 0.05, 0.0)

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


func _clear() -> void:
	for node: Node in get_nodes_in_group(&"enemies"):
		node.free()
	for child: Node in _room.get_children():
		var kind: String = child.get_script().get_global_name() if child.get_script() != null else ""
		if kind == "DamageNumber":
			child.free()
	await _frames(2)


# Враг из сцены на месте и без поведения (не падает, не атакует): только геометрия и урон.
func _enemy(scene_name: String, pos: Vector3 = ENEMY_POS, yaw: float = 0.0, modifier: EnemyModifier = null):
	var enemy = (load("res://enemies/%s.tscn" % scene_name) as PackedScene).instantiate()
	enemy.settings = enemy.settings.duplicate()
	enemy.settings.shield_capacity = 0.0
	enemy.health_scale = 100.0
	if modifier != null:
		enemy.apply_modifier(modifier)
	enemy.rotation.y = yaw
	_room.add_child(enemy)
	enemy.global_position = pos
	enemy.set_physics_process(false)
	return enemy


func _initialize() -> void:
	create_timer(300.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	root.get_node("Progress").reset()
	_room = (load("res://rooms/test_room.tscn") as PackedScene).instantiate()
	_room.get_node("Enemies").free()
	_room.get_node("Dummies").queue_free()
	root.add_child(_room)
	await _frames(10)
	_player = _room.get_node("Player")
	await _run()
	print("=== FAILS: ", _fails)
	quit(_fails)


func _run() -> void:
	print("--- Данные и метка")
	var data_ok: bool = true
	for key: String in TYPES:
		var settings: EnemySettings = load("res://data/content/enemies/%s.tres" % key)
		data_ok = data_ok and settings.weak_point_multiplier > 1.0 and settings.weak_point_radius > 0.0
	_check(data_ok, "у всех %d типов врагов есть слабое место (множитель больше 1, радиус больше нуля)" % TYPES.size())
	var gunner = _enemy("gunner")
	var s: EnemySettings = gunner.settings
	var marker: Node3D = gunner.get_node_or_null("WeakPoint")
	_check(marker != null and marker.visible and gunner.has_weak_point() and marker.position.is_equal_approx(s.weak_point_offset), "на теле светится метка слабого места в заданной точке")
	_check(gunner.get_weak_point_center().is_equal_approx(gunner.global_position + s.weak_point_offset), "центр слабого места в мире: позиция врага плюс смещение")
	_check(is_equal_approx(gunner.get_weak_point_multiplier_at(gunner.get_weak_point_center()), s.weak_point_multiplier), "в центре слабого места множитель из данных (%.1f)" % s.weak_point_multiplier)
	_check(is_equal_approx(gunner.get_weak_point_multiplier_at(gunner.global_position + Vector3(0.0, 0.1, 0.0)), 1.0), "ноги и прочее тело множителя не дают")
	await _clear()

	print("--- Поворот и размер")
	var turned = _enemy("gunner", ENEMY_POS, PI * 0.5)
	var local_offset: Vector3 = turned.settings.weak_point_offset
	_check(turned.get_weak_point_center().is_equal_approx(turned.global_position + Basis(Vector3.UP, PI * 0.5) * local_offset), "слабое место поворачивается вместе с врагом")
	await _clear()
	var brute: EnemyModifier = load("res://data/content/modifiers/brute.tres")
	var big = _enemy("gunner", ENEMY_POS, 0.0, brute)
	var small = _enemy("gunner", ENEMY_POS + Vector3(10.0, 0.0, 0.0))
	_check(is_equal_approx(big.get_weak_point_world_radius(), small.get_weak_point_world_radius() * brute.model_scale), "у крупного врага (Громила) слабое место растёт вместе с моделью")
	await _clear()

	print("--- Урон выстрела")
	var weapon = _player.get_weapon()
	weapon.crit_bonus = -10.0
	var body_target = _enemy("gunner", ENEMY_POS)
	var weak_target = _enemy("gunner", ENEMY_POS + Vector3(10.0, 0.0, 0.0))
	var body_before: float = body_target.health
	var weak_before: float = weak_target.health
	weapon._apply_hit(body_target, body_target.global_position + Vector3(0.0, 0.1, 0.0))
	weapon._apply_hit(weak_target, weak_target.get_weak_point_center())
	var body_loss: float = body_before - body_target.health
	var weak_loss: float = weak_before - weak_target.health
	_check(body_loss > 0.0 and is_equal_approx(weak_loss / body_loss, s.weak_point_multiplier), "выстрел в слабое место бьёт в %.1f раза сильнее (%.1f против %.1f), крита в оружии нет" % [weak_loss / body_loss, weak_loss, body_loss])
	var seen: Dictionary = {"crit": false}
	weapon.hit_confirmed.connect(func(is_crit: bool, _killed: bool) -> void: seen["crit"] = is_crit)
	weapon._apply_hit(weak_target, weak_target.get_weak_point_center())
	_check(seen["crit"], "попадание в слабое место подтверждается как крит")
	await _clear()
	var dead = _enemy("gunner")
	dead.health = 0.5
	dead.take_hit(DamageInfo.create(100.0, false, dead.global_position))
	_check(dead.is_dead and is_equal_approx(dead.get_weak_point_multiplier_at(dead.get_weak_point_center()), 1.0), "у погибшего врага слабого места уже нет")
	await _clear()

	print("--- Слабое место на теле: луч спереди")
	var misses: Array[String] = []
	for key: String in TYPES:
		var target = _enemy(key, ENEMY_POS)
		await _frames(2)
		var center: Vector3 = target.get_weak_point_center()
		var space: PhysicsDirectSpaceState3D = _room.get_world_3d().direct_space_state
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(center + Vector3(0.0, 0.0, -4.0), center + Vector3(0.0, 0.0, 0.6), 4)
		var hit: Dictionary = space.intersect_ray(query)
		if hit.is_empty() or hit["collider"] != target or target.get_weak_point_multiplier_at(hit["position"]) <= 1.0:
			misses.append(key)
		target.free()
	_check(misses.is_empty(), "выстрел спереди в центр слабого места попадает в него у всех типов (мимо: %s)" % ", ".join(misses))
	await _clear()
