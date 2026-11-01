@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Закрытие вертикальных стыков и софтлок на лестнице (№85, №87). Бой в комнате не начинается, пока игрок стоит на лестнице стыка
## (в проёме пола или потолка), и плита проёма не закрывается у него перед носом; когда он целиком внутри комнаты, бой начинается, плита
## закрывается и игрок остаётся по эту сторону. Плита не закрывается на теле игрока и закроется, когда он выйдет.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_vertical_lock.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.

const STATE_IDLE: int = 0
const STATE_ACTIVE: int = 1

var _fails: int = 0
var _scene: Node
var _builder
var _player
var _settings: ZoneSettings


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


func _initialize() -> void:
	create_timer(900.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	_settings = root.get_node("Config").data.zones
	root.size = Vector2i(1920, 1080)
	_scene = (load("res://run/run.tscn") as PackedScene).instantiate()
	root.add_child(_scene)
	_builder = _scene.get_node("Zone")
	_player = _scene.get_node("Player")
	# Здание зоны проверяется не на выживание: здоровье возвращается при уроне.
	_player.damaged.connect(func(_amount: float, _from: Vector3) -> void: _player.set_health(_player.max_health))
	await _wait_built()
	await _scenario(true)
	await _scenario(false)
	print("=== FAILS: ", _fails)
	quit(_fails)


# Ищет зону, где у боевой комнаты есть плита стыка в полу (floor_type) или в потолке.
func _find_door(floor_type: bool) -> Dictionary:
	for zone: int in range(1, _settings.zones_in_department + 1):
		for seed_index: int in 3:
			_settings.debug_seed = 1000 + seed_index * 37
			_scene.run_seed = 700 + seed_index
			_scene.generate(zone)
			await _wait_built()
			for controller in _builder.controllers:
				if controller.kind != RoomDefinition.Kind.COMBAT:
					continue
				for door in controller.doors:
					var on_floor: bool = door.global_position.y < controller.room.global_position.y + 1.0
					if door.is_vertical and on_floor == floor_type:
						return {"controller": controller, "door": door}
	return {}


# Держит игрока в точке (скорость и тяжесть не уносят его), пока идут кадры.
func _hold(feet: Vector3, frames: int) -> void:
	for i: int in frames:
		_player.global_position = feet
		_player.velocity = Vector3.ZERO
		await physics_frame


func _scenario(floor_type: bool) -> void:
	var title: String = "плита в полу комнаты (лестница снизу)" if floor_type else "плита в потолке комнаты (лестница сверху)"
	print("--- ", title)
	var found: Dictionary = await _find_door(floor_type)
	_check(not found.is_empty(), "нашлась боевая комната с вертикальным стыком: %s" % title)
	if found.is_empty():
		return
	var controller = found["controller"]
	var door = found["door"]
	var room: RoomPiece = controller.room
	var box: AABB = room.get_trigger_box()
	var hole_local: Vector3 = room.to_local(door.global_position)
	_check(controller.state == STATE_IDLE and not door.is_closed, "до боя плита открыта, контроллер ждёт игрока")
	# Игрок на лестнице стыка: ногами в плите пола или головой выше низа потолка.
	var feet_local: Vector3 = Vector3(hole_local.x, -0.8 if floor_type else box.end.y - 1.0, hole_local.z)
	await _hold(room.to_global(feet_local), 20)
	_check(controller.state == STATE_IDLE and not door.is_closed, "игрок на лестнице стыка (ноги %.1f м от пола): бой не начался, плита открыта" % feet_local.y)
	# Предохранитель: плита не закрывается на теле игрока.
	door.set_closed(true)
	_check(not door.is_closed, "плита не закрылась, пока в ней стоит игрок")
	await _hold(room.to_global(feet_local), 5)
	_check(not door.is_closed, "и дальше ждёт, пока игрок в ней")
	_player.global_position = Vector3(0.0, -400.0, 0.0)
	await _frames(6)
	_check(door.is_closed, "игрок вышел из объёма плиты: плита закрылась")
	door.set_closed(false)
	await _frames(3)
	# Игрок целиком внутри комнаты: у плиты стыка по горизонтали, ногами на верхе пола (над проёмом) или головой под потолком.
	var inside_y: float = 0.05 if floor_type else box.end.y - 1.9
	var inside_local: Vector3 = Vector3(hole_local.x, inside_y, hole_local.z)
	await _hold(room.to_global(inside_local), 12)
	_check(controller.state == STATE_ACTIVE, "игрок целиком внутри комнаты: бой начался")
	var all_closed: bool = true
	for each in controller.doors:
		if not each.is_closed:
			all_closed = false
	_check(all_closed and door.is_closed, "двери и плита стыка закрылись (%d)" % controller.doors.size())
	await _frames(4)
	_check(room.is_actor_inside(_player.global_position, 1.8), "игрок остался внутри комнаты, не в стене")
	for enemy in controller.enemies.duplicate():
		enemy.take_hit(DamageInfo.create(1.0e9, false, enemy.global_position + Vector3(0, 1, 0)))
	await _frames(10)
	_check(controller.state == 2 and not door.is_closed, "бой окончен: плита открылась")
