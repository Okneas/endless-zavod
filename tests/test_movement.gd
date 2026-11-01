@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Движение: ходьба, спринт, прыжки, приседание, подкат, хук, HUD здоровья.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_movement.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.

# Значения enum Player.State (GROUND, AIR, SLIDE, HOOK): сам тип тут нельзя, он зависит от autoload.
const S_GROUND: int = 0
const S_AIR: int = 1
const S_SLIDE: int = 2
const S_HOOK: int = 3

var _fails: int = 0
var _room: Node
var _player
var _head: Node3D
var _camera: Camera3D
var _hook


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _until(cond: Callable, max_frames: int) -> int:
	for i: int in max_frames:
		if cond.call():
			return i
		await physics_frame
	return -1


func _release_all() -> void:
	for a: String in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "hook", "sprint"]:
		Input.action_release(a)


func _place(pos: Vector3, yaw_deg: float = 0.0, pitch_deg: float = 0.0) -> void:
	_release_all()
	await _frames(3)
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.rotation.y = deg_to_rad(yaw_deg)
	_player.set_look_pitch(deg_to_rad(pitch_deg))
	await _frames(40)


func _tap(action: String) -> void:
	Input.action_press(action)
	await _frames(2)
	Input.action_release(action)


func _real_key(code: Key, pressed: bool, shift: bool = false, ctrl: bool = false) -> void:
	# Событие как от Windows: с флагами модификаторов и расположением левой клавиши.
	var e := InputEventKey.new()
	e.device = 16
	e.keycode = code
	e.physical_keycode = code
	e.key_label = code
	e.pressed = pressed
	e.shift_pressed = shift
	e.ctrl_pressed = ctrl
	if code == KEY_SHIFT or code == KEY_CTRL:
		e.location = KEY_LOCATION_LEFT
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func _heading_deg() -> float:
	# Угол направления движения вправо от «севера» (-Z), градусы.
	return rad_to_deg(atan2(_player.velocity.x, -_player.velocity.z))


func _initialize() -> void:
	create_timer(900.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	_room = (load("res://rooms/test_room.tscn") as PackedScene).instantiate()
	_room.get_node("Enemies").free()
	root.add_child(_room)
	_room.get_node("Dummies").queue_free()
	await _frames(10)
	_player = _room.get_node("Player")
	_head = _player.get_node("Head")
	_camera = _player.get_node("Head/Camera3D")
	_hook = _player.get_node("Hook")
	await _run()
	_release_all()
	print("=== FAILS: ", _fails)
	quit(_fails)


func _run() -> void:
	var m: MovementSettings = _player.movement
	var h: HookSettings = _hook.settings

	print("--- Настройки и сцена")
	_check(Engine.physics_ticks_per_second == 120, "120 тиков физики (Engine: %d)" % Engine.physics_ticks_per_second)
	_check(_player.health == _player.settings.max_health and _player.max_health == _player.settings.max_health, "здоровье равно настройке (%d)" % _player.settings.max_health)
	_check(InputMap.has_action("sprint") and not InputMap.has_action("slide"), "есть sprint, нет slide")
	var own_actions: Array = InputMap.get_actions().filter(func(a: StringName) -> bool: return not String(a).begins_with("ui_"))
	_check(own_actions.size() == 31 and InputMap.has_action("debug_panel") and InputMap.has_action("debug_zone_next") and InputMap.has_action("debug_zone_prev") and InputMap.has_action("debug_zone_reseed") and InputMap.has_action("aim") and InputMap.has_action("debug_give_weapon") and InputMap.has_action("debug_give_item") and InputMap.has_action("inventory_equip"), "своих действий 31, включая aim, отладочную выдачу, пять действий инвентаря, три отладочных действия зоны и панель отладки (найдено %d)" % own_actions.size())
	_check(_player.collision_layer == 2 and _player.collision_mask == 5, "слои игрока: слой 2, маска 5 (мир и мишени)")

	print("--- Земля, ходьба, спринт")
	await _place(Vector3(0, 0.05, 18))
	_check(_player.is_on_floor() and _player.state == S_GROUND, "игрок стоит на полу, состояние GROUND")
	_check(absf(_player.global_position.y) < 0.05, "высота над полом ~0 (y=%.3f)" % _player.global_position.y)
	_check(_player.get_horizontal_speed() < 0.01, "на месте скорость 0")
	Input.action_press("move_forward")
	await _frames(120)
	_check(absf(_player.get_horizontal_speed() - m.walk_speed) < 0.1, "ходьба вперёд: %.2f м/с (ждём %.1f)" % [_player.get_horizontal_speed(), m.walk_speed])
	Input.action_press("sprint")
	await _frames(60)
	_check(absf(_player.get_horizontal_speed() - m.sprint_speed) < 0.1, "спринт: %.2f м/с (ждём %.1f)" % [_player.get_horizontal_speed(), m.sprint_speed])
	_check(_player.get_state_key() == "SPRINT", "ключ состояния SPRINT")
	Input.action_release("sprint")
	await _frames(60)
	_check(absf(_player.get_horizontal_speed() - m.walk_speed) < 0.1, "отпустили Shift: вернулись к ходьбе (%.2f)" % _player.get_horizontal_speed())

	print("--- Спринт только вперёд")
	await _place(Vector3(0, 0.05, 18))
	Input.action_press("sprint")
	Input.action_press("move_left")
	await _frames(90)
	_check(absf(_player.get_horizontal_speed() - m.walk_speed) < 0.1, "спринт + движение вбок: остаётся ходьба (%.2f)" % _player.get_horizontal_speed())

	print("--- Прыжок и двойной прыжок")
	await _place(Vector3(0, 0.05, 18))
	var base_y: float = _player.global_position.y
	var max_y: float = base_y
	Input.action_press("jump")
	for i: int in 150:
		await physics_frame
		Input.action_release("jump")
		max_y = maxf(max_y, _player.global_position.y)
	var apex1: float = max_y - base_y
	_check(absf(apex1 - m.jump_height) < 0.1, "высота прыжка %.2f м (ждём %.1f)" % [apex1, m.jump_height])
	_check(_player.is_on_floor() and _player.state == S_GROUND, "после прыжка приземлились")
	# Двойной прыжок: второе нажатие в воздухе даёт новый импульс, третье уже нет.
	await _tap("jump")
	await _frames(30)
	var vy_before: float = _player.velocity.y
	await _tap("jump")
	var vy_after_air_jump: float = _player.velocity.y
	_check(vy_after_air_jump > vy_before + 3.0, "прыжок в воздухе даёт импульс (vy %.1f -> %.1f)" % [vy_before, vy_after_air_jump])
	_check((sqrt(2.0 * m.gravity * m.air_jump_height) - m.gravity * 4.0 / 120.0) < vy_after_air_jump + 0.001 and vy_after_air_jump < sqrt(2.0 * m.gravity * m.air_jump_height) + 0.001, "импульс воздушного прыжка соответствует высоте %.1f м" % m.air_jump_height)
	await _frames(45)
	var vy_before3: float = _player.velocity.y
	await _tap("jump")
	_check(_player.velocity.y < vy_before3, "третий прыжок не даёт импульса (vy %.1f -> %.1f)" % [vy_before3, _player.velocity.y])
	await _until(func() -> bool: return _player.is_on_floor(), 200)
	await _frames(5)
	await _tap("jump")
	await _frames(20)
	await _tap("jump")
	_check(_player.velocity.y > 0.0 and not _player.is_on_floor(), "после приземления двойной прыжок снова доступен")
	await _until(func() -> bool: return _player.is_on_floor(), 300)

	print("--- Приседание, балка, подъём")
	await _place(Vector3(0, 0.05, 18))
	Input.action_press("crouch")
	await _frames(40)
	var capsule: CapsuleShape3D = _player.get_node("CollisionShape3D").shape
	_check(is_equal_approx(capsule.height, m.crouch_height) and _player.get(&"_crouching") == true, "присед: капсула %.2f м" % capsule.height)
	_check(absf(_head.position.y - m.crouch_eye_height) < 0.02, "камера опустилась до %.2f (y=%.3f)" % [m.crouch_eye_height, _head.position.y])
	Input.action_press("move_forward")
	await _frames(90)
	_check(absf(_player.get_horizontal_speed() - m.crouch_speed) < 0.1, "в приседе скорость %.2f (ждём %.1f), подката не было" % [_player.get_horizontal_speed(), m.crouch_speed])
	_check(_player.state == S_GROUND, "присед на малой скорости не запускает подкат")
	Input.action_release("crouch")
	await _frames(60)
	_check(is_equal_approx(capsule.height, m.stand_height) and _player.get(&"_crouching") == false, "отпустили Ctrl: встали, капсула %.2f м" % capsule.height)
	_check(absf(_head.position.y - m.stand_eye_height) < 0.02, "камера вернулась на %.2f" % m.stand_eye_height)
	# Под балкой: просвет 1.3 м ниже роста 1.8 м, но выше приседа 1.1 м.
	await _place(Vector3(-10, 0.05, 15))
	Input.action_press("crouch")
	Input.action_press("move_forward")
	await _until(func() -> bool: return _player.global_position.z < 10.0, 400)
	Input.action_release("crouch")
	await _frames(30)
	_check(_player.get(&"_crouching") == true, "под балкой отпустили Ctrl: остаёмся в приседе (z=%.1f)" % _player.global_position.z)
	await _until(func() -> bool: return _player.global_position.z < 7.0, 400)
	await _frames(40)
	_check(_player.get(&"_crouching") == false, "вышли из-под балки: встали (z=%.1f)" % _player.global_position.z)

	print("--- Подкат: старт, затухание, конец")
	# Комната 40 x 40 м: на скоростях автора (спринт 15, потолок подката 20) подкат до конца не помещается, враг упирался бы в стену.
	# На время этого раздела скорости ограничены прежними (спринт 11, потолок 14), потом возвращаются.
	var saved_sprint: float = m.sprint_speed
	var saved_slide_max: float = m.slide_max_speed
	m.sprint_speed = minf(m.sprint_speed, 11.0)
	m.slide_max_speed = minf(m.slide_max_speed, 14.0)
	await _place(Vector3(0, 0.05, 18))
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(100)
	var pre_speed: float = _player.get_horizontal_speed()
	Input.action_press("crouch")
	# У программного ввода just_pressed приходит на тик позже is_action_pressed: ждём старта подката
	# и берём скорость кадра перед ним (в этот кадр уже действовало приседание).
	var speed_before_slide: float = pre_speed
	for i: int in 6:
		await physics_frame
		if _player.state == S_SLIDE:
			break
		speed_before_slide = _player.get_horizontal_speed()
	var slide_speed: float = _player.get_horizontal_speed()
	var expected_boost: float = minf(speed_before_slide * m.slide_start_boost, m.slide_max_speed) - m.slide_deceleration / 120.0
	_check(_player.state == S_SLIDE, "Ctrl на спринте: подкат (скорость до %.2f)" % pre_speed)
	_check(absf(slide_speed - expected_boost) < 0.05, "рывок на старте: %.2f м/с (ждём %.2f = x%.2f от %.2f)" % [slide_speed, expected_boost, m.slide_start_boost, speed_before_slide])
	_check(slide_speed > pre_speed, "рывок поднял скорость выше спринта (%.2f -> %.2f)" % [pre_speed, slide_speed])
	await _frames(30)
	_check(absf((slide_speed - _player.get_horizontal_speed()) - m.slide_deceleration * 0.25) < 0.3, "скорость падает на %.2f за 0.25 с (ждём %.2f = торможение %.1f)" % [slide_speed - _player.get_horizontal_speed(), m.slide_deceleration * 0.25, m.slide_deceleration])
	_check(absf(_head.position.y - m.slide_eye_height) < 0.05, "в подкате камера низко (y=%.2f)" % _head.position.y)
	var frames_left: int = await _until(func() -> bool: return _player.state != S_SLIDE, 400)
	var slide_seconds: float = (frames_left + 30) / 120.0
	var expected_seconds: float = (slide_speed - m.crouch_speed) / m.slide_deceleration
	_check(frames_left >= 0 and slide_seconds <= expected_seconds + 0.15 and slide_seconds > expected_seconds * 0.7, "подкат длится %.2f с (ждём ~%.2f)" % [slide_seconds, expected_seconds])
	_check(_player.state == S_GROUND and _player.get(&"_crouching") == true, "конец подката: присед на земле, Ctrl зажат")
	m.sprint_speed = saved_sprint
	m.slide_max_speed = saved_slide_max

	print("--- Подкат: отпустил Ctrl - подкат кончился")
	await _place(Vector3(0, 0.05, 18))
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(100)
	Input.action_press("crouch")
	await _frames(30)
	_check(_player.state == S_SLIDE, "подкат идёт")
	Input.action_release("crouch")
	await _frames(3)
	_check(_player.state == S_GROUND, "отпустили Ctrl: подкат закончился")
	await _frames(60)
	_check(_player.get(&"_crouching") == false and is_equal_approx(capsule.height, m.stand_height), "встали после подката")

	print("--- Подкат: прыжок сохраняет скорость, подкат при приземлении")
	await _place(Vector3(0, 0.05, 18))
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(100)
	Input.action_press("crouch")
	await _frames(20)
	var speed_before_jump: float = _player.get_horizontal_speed()
	Input.action_press("jump")
	await physics_frame
	Input.action_release("jump")
	await physics_frame
	_check(_player.state == S_AIR, "прыжок из подката: состояние AIR")
	_check(absf(_player.velocity.y - (sqrt(2.0 * m.gravity * m.jump_height) - m.gravity / 120.0)) < 0.6, "вертикальный импульс прыжка (vy=%.2f)" % _player.velocity.y)
	_check(_player.get_horizontal_speed() > speed_before_jump - 0.3, "горизонтальная скорость сохранена (%.2f -> %.2f)" % [speed_before_jump, _player.get_horizontal_speed()])
	await _frames(40)
	_check(_player.get_horizontal_speed() > speed_before_jump - 0.5, "инерция держится в полёте (%.2f)" % _player.get_horizontal_speed())
	await _until(func() -> bool: return _player.state != S_AIR, 300)
	_check(_player.state == S_SLIDE, "приземлились с зажатым Ctrl на скорости: подкат (slide-hop), скорость %.2f" % _player.get_horizontal_speed())
	await _place(Vector3(0, 0.05, 18))
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(100)
	await _tap("jump")
	await _frames(10)
	Input.action_press("crouch")
	_check(_player.state == S_AIR, "Ctrl в воздухе подкат сразу не запускает")
	await _until(func() -> bool: return _player.state != S_AIR, 300)
	_check(_player.state == S_SLIDE, "приземление после обычного прыжка с Ctrl: подкат")

	print("--- Подкат с обычной ходьбы (порог ниже скорости ходьбы)")
	_check(m.slide_min_speed < m.walk_speed, "порог подката %.1f ниже ходьбы %.1f" % [m.slide_min_speed, m.walk_speed])
	await _place(Vector3(0, 0.05, 18))
	Input.action_press("move_forward")
	await _frames(60)
	var walk_speed_now: float = _player.get_horizontal_speed()
	Input.action_press("crouch")
	var walk_slide_started: int = await _until(func() -> bool: return _player.state == S_SLIDE, 10)
	_check(walk_slide_started >= 0, "ходьба %.1f м/с + Ctrl: подкат" % walk_speed_now)
	var walk_slide_speed: float = _player.get_horizontal_speed()
	_check(walk_slide_speed > walk_speed_now, "рывок поднял скорость выше ходьбы (%.2f -> %.2f)" % [walk_speed_now, walk_slide_speed])
	Input.action_release("crouch")
	Input.action_release("move_forward")
	await _frames(30)

	print("--- Настоящие события клавиш (с флагами модификаторов)")
	await _place(Vector3(0, 0.05, 18))
	_real_key(KEY_W, true)
	_real_key(KEY_SHIFT, true, true)
	await _frames(60)
	_real_key(KEY_CTRL, true, true, true)
	await _frames(4)
	_check(_player.state == S_SLIDE, "W + Shift, затем Ctrl (настоящие события): подкат")
	_real_key(KEY_SPACE, true, true, true)
	await _frames(4)
	_real_key(KEY_SPACE, false, true, true)
	_check(_player.state == S_AIR and _player.velocity.y > 5.0, "Space в подкате: прыжок (настоящее событие)")
	_real_key(KEY_CTRL, false, true, false)
	_real_key(KEY_SHIFT, false)
	_real_key(KEY_W, false)
	await _place(Vector3(0, 0.05, 18))
	_real_key(KEY_W, true)
	await _frames(60)
	_real_key(KEY_CTRL, true, false, true)
	await _frames(4)
	_check(_player.state == S_SLIDE, "только W (ходьба), затем Ctrl (настоящие события): подкат")
	_real_key(KEY_CTRL, false)
	_real_key(KEY_W, false)
	await _place(Vector3(4, 0.05, 2), 0.0, 25.7)
	_real_key(KEY_Q, true)
	await _frames(4)
	_check(_player.state == S_HOOK, "Q (настоящее событие): хук")
	_real_key(KEY_Q, false)
	await _frames(4)
	_check(_player.state != S_HOOK, "Q отпущена: хук отпущен")
	await _until(func() -> bool: return _player.is_on_floor(), 400)
	print("--- Подкат: доворот")
	for side: Array in [["move_right", 1.0], ["move_left", -1.0]]:
		await _place(Vector3(0, 0.05, 18))
		Input.action_press("move_forward")
		Input.action_press("sprint")
		await _frames(100)
		Input.action_press("crouch")
		await physics_frame
		var angle_start: float = _heading_deg()
		Input.action_press(side[0])
		await _frames(60)
		var turned: float = (_heading_deg() - angle_start) * float(side[1])
		var expected_turn: float = m.slide_steer_degrees_per_second * 0.5
		_check(_player.state == S_SLIDE and absf(turned - expected_turn) < 6.0, "%s: направление повернулось на %.1f° за 0.5 с (ждём ~%.1f°)" % [side[0], turned, expected_turn])

	print("--- Хук: цель, дальность")
	await _place(Vector3(0, 0.05, 16), 0.0, 80.0)
	await _tap("hook")
	_check(_player.state != S_HOOK and not _hook.is_attached, "прицел в небо: хук не цепляется")
	await _place(Vector3(0, 0.05, 16), 0.0, 0.0)
	var old_range: float = h.max_range
	h.max_range = 10.0
	await _tap("hook")
	_check(not _hook.is_attached, "стена дальше max_range: хук не цепляется")
	h.max_range = old_range
	await _frames(5)
	_hook.release()
	_player.state = S_AIR

	print("--- Хук: мягкий старт, разгон, долёт, подброс, пружина")
	await _place(Vector3(4, 0.05, 2), 0.0, 25.7)
	Input.action_press("hook")
	await physics_frame
	await physics_frame
	_check(_player.state == S_HOOK and _hook.is_attached, "хук зацепился за башню")
	_check(_player.get(&"_air_jumps_left") == m.air_jumps, "прыжок в воздухе восстановлен при зацепе")
	var target: Vector3 = _hook.get("_target")
	var dt: float = 1.0 / 120.0
	var prev_speed: float = _player.velocity.length()
	var max_accel: float = 0.0
	var monotonic: bool = true
	var speed_at_0_1: float = -1.0
	var speed_at_ramp: float = -1.0
	var frames_to_arrive: int = -1
	var t_since: float = 2.0 * dt
	for i: int in 600:
		var dist: float = _camera.global_position.distance_to(target)
		if _hook.is_hanging:
			frames_to_arrive = i
			break
		var s: float = _player.velocity.length()
		if dist > 1.5:
			max_accel = maxf(max_accel, (s - prev_speed) / dt)
			if s < prev_speed - 0.01:
				monotonic = false
		if absf(t_since - 0.1) < dt * 0.6:
			speed_at_0_1 = s
		if absf(t_since - h.acceleration_ramp_time) < dt * 0.6:
			speed_at_ramp = s
		prev_speed = s
		t_since += dt
		await physics_frame
	_check(frames_to_arrive > 0, "долетел и вошёл в пружину за %d кадров (%.2f с)" % [frames_to_arrive, frames_to_arrive / 120.0])
	_check(speed_at_0_1 >= 0.0 and speed_at_0_1 < 1.0, "через 0.1 с скорость ещё мала: %.2f м/с (мягкий старт)" % speed_at_0_1)
	var expected_ramp_speed: float = 0.5 * h.pull_acceleration * h.acceleration_ramp_time
	_check(absf(speed_at_ramp - expected_ramp_speed) < 1.5, "к концу S-кривой (%.2f с) скорость %.2f (ждём ~%.1f)" % [h.acceleration_ramp_time, speed_at_ramp, expected_ramp_speed])
	_check(monotonic, "скорость притягивания только растёт, без рывков вниз")
	_check(max_accel <= h.pull_acceleration * 1.05, "ускорение не выше pull_acceleration: %.1f из %.1f м/с²" % [max_accel, h.pull_acceleration])
	var arrival_pos: Vector3 = _camera.global_position
	_check(_player.velocity.y > 0.0 and _player.velocity.y <= h.arrival_kick_speed + 1.0, "долёт: подброс вверх vy=%.2f (подброс %.1f)" % [_player.velocity.y, h.arrival_kick_speed])
	var peak_above: float = 0.0
	var returned_frame: int = -1
	for i: int in 240:
		await physics_frame
		var rise: float = _camera.global_position.y - target.y
		peak_above = maxf(peak_above, rise)
		if peak_above > 0.2 and returned_frame < 0 and rise < peak_above - 0.2:
			returned_frame = i
	_check(peak_above > 0.2 and peak_above < 1.5, "подбросило выше точки зацепа на %.2f м" % peak_above)
	_check(returned_frame >= 0, "потом пружина тянет обратно к точке (вернулись за %.2f с)" % (returned_frame / 120.0))
	await _frames(240)
	_check(_camera.global_position.distance_to(target) < 0.06, "успокоились в точке зацепа (отклонение %.3f м)" % _camera.global_position.distance_to(target))
	_check(_player.velocity.length() < 0.1 and _player.state == S_HOOK, "висим на месте, скорость %.3f" % _player.velocity.length())
	_check(_player.get_state_key() == "HANG", "ключ состояния HANG")
	var hang_pos: Vector3 = _camera.global_position
	Input.action_release("hook")
	await _frames(3)
	_check(_player.state == S_AIR and not _hook.is_attached, "отпустили кнопку: отцепились, падаем")
	await _frames(30)
	# Падение за 0.25 с по настройке тяжести: не меньше 70% свободного падения (0.5 g t^2), а не фиксированные 0.8 м.
	var expected_drop: float = 0.7 * 0.5 * m.gravity * 0.25 * 0.25
	_check(_camera.global_position.y < hang_pos.y - expected_drop, "после отцепа падаем (y %.2f -> %.2f, ждём ниже на %.2f м)" % [hang_pos.y, _camera.global_position.y, expected_drop])
	await _until(func() -> bool: return _player.is_on_floor(), 300)
	await _frames(5)
	_check(_player.state == S_GROUND, "приземлились, состояние GROUND")

	print("--- Хук: инерция при отпускании до долёта")
	await _place(Vector3(12, 0.05, 4), 0.0, 25.0)
	Input.action_press("hook")
	await physics_frame
	await physics_frame
	_check(_hook.is_attached, "хук зацепился за дальнюю башню")
	var arrive: int = await _until(func() -> bool: return _camera.global_position.distance_to(_hook.get("_target")) < 3.0, 600)
	var release_velocity: Vector3 = _player.velocity
	var release_y: float = _camera.global_position.y
	_check(arrive >= 0 and not _hook.is_hanging, "ещё не долетели (осталось <3 м), скорость %.1f" % release_velocity.length())
	_check(release_velocity.length() > h.pull_speed * 0.8, "к этому моменту разогнались почти до pull_speed (%.1f из %.1f)" % [release_velocity.length(), h.pull_speed])
	Input.action_release("hook")
	var peak_y: float = release_y
	for i: int in 150:
		await physics_frame
		peak_y = maxf(peak_y, _camera.global_position.y)
	var expected_peak: float = release_y + release_velocity.y * release_velocity.y / (2.0 * m.gravity)
	_check(release_velocity.y > 5.0 and absf(peak_y - expected_peak) < 0.5, "инерция сохранена: пик y=%.2f, ждём %.2f (vy при отпускании %.1f)" % [peak_y, expected_peak, release_velocity.y])
	await _until(func() -> bool: return _player.is_on_floor(), 400)
	print("--- Хук во время подката, отмена подката хуком")
	await _place(Vector3(4, 0.05, 6), 0.0, 20.0)
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(60)
	Input.action_press("crouch")
	await _frames(10)
	_check(_player.state == S_SLIDE, "подкат идёт перед хуком")
	Input.action_press("hook")
	await _frames(3)
	_check(_player.state == S_HOOK, "хук прерывает подкат")
	Input.action_release("hook")
	_release_all()
	await _until(func() -> bool: return _player.is_on_floor(), 400)

	print("--- Воздух: поворот камеры и A/D не накручивают скорость (спринт, двойной прыжок)")
	var air_cases: Array = [["без поворота", 0.0, false], ["камера 120 °/с", 1.0, false], ["камера 360 °/с", 3.0, false], ["W+D без камеры", 0.0, true], ["W+D и камера 120 °/с", 1.0, true]]
	for air_case: Array in air_cases:
		var worst_ratio: float = 0.0
		var worst_after: int = 0
		for after: int in range(20, 95, 15):
			await _place(Vector3(0, 0.05, 18))
			Input.action_press("move_forward")
			Input.action_press("sprint")
			if air_case[2]:
				Input.action_press("move_right")
			await _frames(100)
			var start_speed: float = _player.get_horizontal_speed()
			Input.action_press("jump")
			var max_air_speed: float = 0.0
			for tick: int in 200:
				await physics_frame
				if tick == 1:
					Input.action_release("jump")
				if tick == after:
					Input.action_press("jump")
				if tick == after + 1:
					Input.action_release("jump")
				if not _player.is_on_floor() and air_case[1] != 0.0:
					_player.rotate_y(deg_to_rad(air_case[1]))
				max_air_speed = maxf(max_air_speed, _player.get_horizontal_speed())
			var ratio: float = max_air_speed / maxf(start_speed, m.sprint_speed)
			if ratio > worst_ratio:
				worst_ratio = ratio
				worst_after = after
		_check(worst_ratio <= 1.01, "%s: максимум скорости %.2f от спринта (второй прыжок через %d тиков), ждём не выше 1.0" % [air_case[0], worst_ratio, worst_after])

	print("--- Хук в воздухе: падение и боковой полёт не обрываются")
	_release_all()
	await _frames(3)
	_player.global_position = Vector3(4, 5.0, 3)
	_player.velocity = Vector3(5, -8, 0)
	_player.rotation.y = 0.0
	_player.set_look_pitch(deg_to_rad(-3.0))
	_player.state = S_AIR
	await physics_frame
	Input.action_press("hook")
	var prev_v: Vector3 = _player.velocity
	var v_at_attach: Vector3 = Vector3.ZERO
	var attach_tick: int = -1
	for tick: int in 12:
		await physics_frame
		if _player.state == S_HOOK:
			v_at_attach = _player.velocity
			attach_tick = tick
			break
		prev_v = _player.velocity
	_check(attach_tick >= 0, "хук зацепился в воздухе (за %d тиков)" % attach_tick)
	_check((v_at_attach - prev_v).length() < 1.5, "скорость не обрывается в момент зацепа: %s -> %s (скачок %.2f м/с)" % [str(prev_v.snappedf(0.1)), str(v_at_attach.snappedf(0.1)), (v_at_attach - prev_v).length()])
	_check(v_at_attach.length() > prev_v.length() * 0.9, "скорость сохраняется (%.1f из %.1f м/с)" % [v_at_attach.length(), prev_v.length()])
	await _frames(24)
	_check(_player.velocity.x > 3.0, "через 0.2 с боковая скорость ещё есть (vx=%.2f из 5.0), выравнивается постепенно" % _player.velocity.x)
	_check(_player.velocity.dot(v_at_attach.normalized()) > v_at_attach.length() * 0.8, "направление движения меняется плавно")
	var aligned: int = await _until(func() -> bool: return _hook.is_hanging, 600)
	_check(aligned >= 0, "долетел до точки и повис (за %.2f с)" % (aligned / 120.0))
	Input.action_release("hook")
	await _until(func() -> bool: return _player.is_on_floor(), 400)
	print("--- HUD и отладочная надпись")
	var hp_bar: ProgressBar = _room.get_node("Hud/Root/Status/Column/HpRow/HpBar")
	var hp_value: Label = _room.get_node("Hud/Root/Status/Column/HpRow/HpBar/HpValue")
	var armor_row: Control = _room.get_node("Hud/Root/Status/Column/ArmorRow")
	_check(hp_bar.max_value == float(_player.max_health) and hp_bar.value == float(_player.max_health) and hp_value.text == str(_player.max_health), "HP-бар показывает %d/%d" % [_player.max_health, _player.max_health])
	_player.set_health(70)
	_check(hp_bar.value == 70.0 and hp_value.text == "70", "set_health(70): бар и число обновились")
	_player.set_health(500)
	_check(_player.health == _player.max_health, "здоровье не выше максимума")
	_check(not armor_row.visible, "строка Armor скрыта, место под ней зарезервировано")
	_check(_room.get_node("Hud/Root/Crosshair") is Control, "прицел на месте")
	_check(tr("HUD_HP") == "HP" and tr("HUD_ARMOR") == "Броня", "переводы HUD: HP / Броня")
	await _place(Vector3(0, 0.05, 18))
	var overlay_text: String = (_room.get_node("DebugOverlay/Label") as Label).text
	print(overlay_text.replace("\n", " | "))
	_check(overlay_text.contains("Скорость: 0.0 м/с") and overlay_text.contains("Состояние: земля"), "надпись показывает скорость и состояние на русском")
