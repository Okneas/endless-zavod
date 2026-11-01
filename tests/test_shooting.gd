@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Стрельба: части и характеристики, разброс, крит, отдача, перезарядка, прицеливание (прицел оружия), ближний бой, мишени, HUD патронов.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_shooting.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.

const S_GROUND: int = 0
const S_AIR: int = 1
const S_SLIDE: int = 2
const S_HOOK: int = 3

var _fails: int = 0
var _room: Node
var _player
var _weapon
var _camera: Camera3D
var _shots: Array[Dictionary] = []
var _real_spread: float = 0.0


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _release_all() -> void:
	for a: String in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "hook", "sprint", "fire", "aim", "reload", "melee"]:
		Input.action_release(a)


func _tap(action: String, frames: int = 2) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)


func _place(pos: Vector3, pitch_deg: float = 0.0, yaw_deg: float = 0.0) -> void:
	_release_all()
	await _frames(3)
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.rotation.y = deg_to_rad(yaw_deg)
	_player.set_look_pitch(deg_to_rad(pitch_deg))
	await _frames(40)


# Полностью заряженное оружие без накопленного разброса и с отключённым случайным критом.
func _reset_weapon() -> void:
	_weapon.is_reloading = false
	_weapon.ammo = _weapon.stats.magazine_size
	_weapon.stats.spread_deg = _real_spread
	_weapon.set("_bloom", 0.0)
	_weapon.set("_cooldown", 0.0)
	_weapon.set("_fire_buffer", 0.0)
	_weapon.crit_bonus = 0.0
	_weapon.stats.crit_chance = 0.0
	_weapon.motion_speed = 0.0


func _initialize() -> void:
	create_timer(900.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	_room = (load("res://rooms/test_room.tscn") as PackedScene).instantiate()
	_room.get_node("Enemies").free()
	root.add_child(_room)
	await _frames(10)
	_player = _room.get_node("Player")
	_weapon = _player.get_weapon()
	_real_spread = _weapon.stats.spread_deg
	_camera = _player.get_node("Head/Camera3D")
	_weapon.shot_traced.connect(func(direction: Vector3, end_point: Vector3, hit: bool) -> void:
		_shots.append({"dir": direction, "end": end_point, "hit": hit}))
	await _run()
	_release_all()
	print("=== FAILS: ", _fails)
	quit(_fails)


func _run() -> void:
	var dummy = _room.get_node("Dummies/TargetDummy2")   # (0, 0, 2)
	var dummy_max: float = dummy.settings.max_health
	var tr_ok: bool = true

	print("--- Данные: части и характеристики")
	var s: WeaponStats = _weapon.stats
	var expected: Dictionary = _expected_stats(_weapon.definition.parts)
	_check(is_equal_approx(s.damage, expected["damage"]) and is_equal_approx(s.fire_rate, expected["fire_rate"]) and s.magazine_size == expected["magazine"] and s.automatic == expected["automatic"], "урон, темп, магазин и режим совпадают с частями (%.0f, %.1f выстр/с, %d)" % [s.damage, s.fire_rate, s.magazine_size])
	_check(is_equal_approx(s.reload_time, expected["reload"]) and is_equal_approx(s.spread_deg, expected["spread"]) and is_equal_approx(s.weapon_range, expected["range"]), "перезарядка, разброс и дальность совпадают с частями (%.2f с, %.2f°, %.0f м)" % [s.reload_time, s.spread_deg, s.weapon_range])
	_check(is_equal_approx(s.recoil_deg, expected["recoil"]) and is_equal_approx(s.aim_time, expected["aim_time"]) and is_equal_approx(s.aim_zoom, expected["zoom"]), "отдача, время прицеливания и зум совпадают с частями (%.2f°, %.2f с, x%.2f)" % [s.recoil_deg, s.aim_time, s.aim_zoom])
	var test_def: WeaponDefinition = WeaponDefinition.new()
	var b: WeaponPart = load("res://data/content/parts/starter_body.tres")
	var barrel: WeaponPart = WeaponPart.new()
	barrel.part_type = WeaponPart.PartType.BARREL
	barrel.spread_mult = 0.5
	barrel.range_mult = 1.5
	var mag: WeaponPart = WeaponPart.new()
	mag.part_type = WeaponPart.PartType.MAGAZINE
	mag.magazine_size_mult = 1.5
	mag.reload_time_mult = 0.8
	mag.crit_chance_add = 0.1
	test_def.parts.assign([b, barrel, mag])
	var ts: WeaponStats = test_def.compute_stats()
	_check(is_equal_approx(ts.spread_deg, b.base_spread_deg * b.spread_mult * 0.5) and ts.magazine_size == maxi(1, roundi(b.base_magazine_size * b.magazine_size_mult * 1.5)) and is_equal_approx(ts.reload_time, b.base_reload_time * b.reload_time_mult * 0.8) and is_equal_approx(ts.weapon_range, b.base_range * b.range_mult * 1.5) and is_equal_approx(ts.crit_chance, b.base_crit_chance + b.crit_chance_add + 0.1), "части сдвигают характеристики множителями (дуло x0.5 разброс, магазин x1.5 и x0.8 перезарядка)")
	_check(is_equal_approx(_weapon.crit_bonus, _player.settings.crit_chance), "крит игрока берётся из настроек игрока (%.0f%%)" % (_player.settings.crit_chance * 100.0))

	print("--- Стрельба: одиночные, темп, буфер")
	await _place(Vector3(0, 0.05, 12), -4.29)
	_reset_weapon()
	_weapon.stats.spread_deg = 0.0
	var ammo0: int = _weapon.ammo
	_shots.clear()
	await _tap("fire")
	_check(_weapon.ammo == ammo0 - 1 and _shots.size() == 1, "выстрел: патроны %d -> %d" % [ammo0, _weapon.ammo])
	await _frames(40)
	_reset_weapon()
	_weapon.stats.spread_deg = 0.0
	_shots.clear()
	Input.action_press("fire")
	await _frames(90)
	Input.action_release("fire")
	_check(_shots.size() == 1, "удержание кнопки не даёт автоогня: выстрелов %d" % _shots.size())
	await _frames(40)
	_reset_weapon()
	_weapon.stats.spread_deg = 0.0
	_shots.clear()
	var cooldown: float = 1.0 / _weapon.stats.fire_rate
	var buffer: float = _weapon.shooting.fire_buffer_time
	# Второй клик, когда до конца паузы остаётся меньше времени буфера, запоминается и срабатывает.
	var gap_late: int = maxi(1, roundi((cooldown - buffer * 0.5) * 120.0) - 3)
	await _tap("fire")
	await _frames(gap_late)
	await _tap("fire")
	await _frames(int(cooldown * 120.0) + 20)
	_check(_shots.size() == 2, "второй клик за %.2f с до конца паузы запомнен буфером и сработал: выстрелов %d" % [buffer * 0.5, _shots.size()])
	await _frames(40)
	_reset_weapon()
	_weapon.stats.spread_deg = 0.0
	_shots.clear()
	await _tap("fire")
	await _frames(4)
	await _tap("fire")
	await _frames(int(cooldown * 120.0) + 20)
	if cooldown - buffer > 0.08:
		_check(_shots.size() == 1, "клик слишком рано (0.05 с) не засчитывается: выстрелов %d" % _shots.size())
	else:
		_check(true, "проверка раннего клика пропущена: буфер %.2f с почти как пауза между выстрелами %.2f с" % [buffer, cooldown])

	print("--- Попадание, урон, крит")
	await _frames(40)
	_reset_weapon()
	_weapon.stats.spread_deg = 0.0
	dummy.health = dummy_max
	await _tap("fire")
	_check(is_equal_approx(dummy.health, dummy_max - _weapon.stats.damage), "попадание в мишень: %.0f -> %.0f (урон оружия %.0f)" % [dummy_max, dummy.health, _weapon.stats.damage])
	_check(_shots.back()["hit"] and absf(_shots.back()["end"].z - 2.4) < 0.5, "луч упёрся в мишень (z=%.2f)" % _shots.back()["end"].z)
	await _frames(40)
	_reset_weapon()
	_weapon.stats.spread_deg = 0.0
	_weapon.crit_bonus = 1.0
	var before: float = dummy.health
	var crit_state: Dictionary = {"crit": false}
	var crit_cb: Callable = func(is_crit: bool, _killed: bool) -> void: crit_state["crit"] = is_crit
	_weapon.hit_confirmed.connect(crit_cb)
	await _tap("fire")
	_weapon.hit_confirmed.disconnect(crit_cb)
	_check(crit_state["crit"] and is_equal_approx(before - dummy.health, _weapon.stats.damage * _weapon.shooting.crit_multiplier), "крит: урон x%.1f (%.0f)" % [_weapon.shooting.crit_multiplier, before - dummy.health])
	# Частота крита при 2%: напрямую через _apply_hit, чтобы не тратить патроны и время.
	var crit_p: float = _player.settings.crit_chance
	_weapon.crit_bonus = crit_p
	dummy.health = 1.0e9
	var crit_counter: Dictionary = {"n": 0}
	var count_cb: Callable = func(is_crit: bool, _killed: bool) -> void:
		if is_crit:
			crit_counter["n"] += 1
	_weapon.hit_confirmed.connect(count_cb)
	_weapon.rng.seed = 12345
	for i: int in 5000:
		_weapon.call("_apply_hit", dummy, dummy.global_position)
	_weapon.hit_confirmed.disconnect(count_cb)
	var rate: float = crit_counter["n"] / 5000.0
	_check(absf(rate - crit_p) < 4.0 * sqrt(crit_p * (1.0 - crit_p) / 5000.0) + 0.002, "частота крита при %.0f%%: %.4f из 5000 попаданий" % [crit_p * 100.0, rate])
	dummy.health = dummy_max
	_reset_weapon()

	print("--- Дальность, стена, метки")
	await _frames(40)
	_weapon.stats.spread_deg = 0.0
	var old_range: float = _weapon.stats.weapon_range
	_weapon.stats.weapon_range = 5.0
	_shots.clear()
	dummy.health = dummy_max
	await _tap("fire")
	_check(is_equal_approx(dummy.health, dummy_max) and not _shots.back()["hit"], "за пределами дальности (5 м) попадания нет")
	_weapon.stats.weapon_range = old_range
	await _frames(40)
	await _place(Vector3(0, 0.05, 12), 0.0)
	_reset_weapon()
	_weapon.stats.spread_deg = 0.0
	var effects: Node3D = _weapon.get("_effects")
	var children_before: int = effects.get_child_count()
	# Идём «над» мишенью: смотрим чуть выше, чтобы попасть в северную стену.
	_player.set_look_pitch(deg_to_rad(8.0))
	_shots.clear()
	await _tap("fire")
	_check(_shots.back()["hit"] and effects.get_child_count() > children_before, "выстрел в стену: попадание, трассер и метка появились (z=%.1f)" % _shots.back()["end"].z)
	await _frames(40)

	print("--- Разброс: конус, движение, воздух, прицеливание, раскрытие (№90)")
	_reset_weapon()
	var base: float = _weapon.stats.spread_deg
	_check(is_equal_approx(_weapon.get_current_spread(), base), "в покое: %.2f° (база дула)" % _weapon.get_current_spread())
	_weapon.motion_speed = _weapon.shooting.full_spread_speed
	_check(is_equal_approx(_weapon.get_current_spread(), base * (1.0 + _weapon.shooting.movement_spread_factor)), "на полной скорости: %.2f° (x%.1f)" % [_weapon.get_current_spread(), 1.0 + _weapon.shooting.movement_spread_factor])
	_weapon.motion_speed = _weapon.shooting.full_spread_speed * 0.5
	_check(is_equal_approx(_weapon.get_current_spread(), base * (1.0 + _weapon.shooting.movement_spread_factor * 0.5)), "на половине скорости: %.2f°" % _weapon.get_current_spread())
	_weapon.motion_speed = 0.0
	_weapon.airborne = true
	_check(is_equal_approx(_weapon.get_current_spread(), base * _weapon.shooting.air_spread_factor), "в воздухе: %.2f° (x%.1f)" % [_weapon.get_current_spread(), _weapon.shooting.air_spread_factor])
	_weapon.airborne = false
	_weapon.aim_amount = 1.0
	_check(is_equal_approx(_weapon.get_current_spread(), base * _weapon.shooting.aim_spread_multiplier), "при полном прицеливании: %.2f° (x%.2f)" % [_weapon.get_current_spread(), _weapon.shooting.aim_spread_multiplier])
	# Картечь (несколько дробин) в прицеливании сужается слабее, чтобы дробины не слипались в точку.
	_weapon.stats.pellets = 6
	_check(is_equal_approx(_weapon.get_current_spread(), base * _weapon.shooting.pellet_aim_spread_multiplier) and _weapon.shooting.pellet_aim_spread_multiplier > _weapon.shooting.aim_spread_multiplier, "дробовик при полном прицеливании: %.2f° (x%.2f, слабее обычного x%.2f)" % [_weapon.get_current_spread(), _weapon.shooting.pellet_aim_spread_multiplier, _weapon.shooting.aim_spread_multiplier])
	_weapon.stats.pellets = 1
	_weapon.aim_amount = 0.0
	# Конус: направления выстрелов лежат внутри угла разброса и покрывают его.
	var worst: float = 0.0
	var sum_angle: float = 0.0
	var forward: Vector3 = -_camera.global_basis.z
	for i: int in 2000:
		var d: Vector3 = _weapon.call("_spread_direction", base)
		var angle: float = rad_to_deg(forward.angle_to(d))
		worst = maxf(worst, angle)
		sum_angle += angle
	_check(worst <= base + 0.001 and worst > base * 0.95, "2000 направлений лежат внутри конуса %.2f° (максимум %.3f°)" % [base, worst])
	var mean_angle: float = sum_angle / 2000.0
	var bias: float = _weapon.shooting.spread_center_bias
	var expected_mean: float = base / (bias + 1.0)
	_check(absf(mean_angle - expected_mean) < maxf(0.05, base * 0.05), "пули по степени %.2f от центра: среднее отклонение %.3f° (ждём %.3f°, равномерно по площади было бы %.3f°)" % [bias, mean_angle, expected_mean, base * 2.0 / 3.0])
	_check(bias <= 0.5 or mean_angle < base * 2.0 / 3.0 - 0.01, "пули тяготеют к центру конуса сильнее, чем при равномерном распределении")
	# Раскрытие при очереди (№90): прибавка в долях кучности, быстрое оружие раскрывается до потолка, медленное не раскрывается.
	_reset_weapon()
	await _place(Vector3(0, 0.05, 12), 8.0)
	_reset_weapon()
	var saved_rate: float = _weapon.stats.fire_rate
	var saved_auto: bool = _weapon.stats.automatic
	var saved_mag: int = _weapon.stats.magazine_size
	var spread_start: float = _weapon.get_current_spread()
	var per_shot: float = _weapon.shooting.bloom_per_shot
	var cap: float = _weapon.shooting.bloom_max
	# Одиночный выстрел раскрывает на долю кучности.
	await _tap("fire")
	var spread_after_1: float = _weapon.get_current_spread()
	_check(spread_after_1 > spread_start * (1.0 + per_shot * 0.8) and spread_after_1 <= spread_start * (1.0 + per_shot) + 0.0001, "выстрел раскрывает разброс на долю кучности: %.2f° -> %.2f° (+%.0f%%)" % [spread_start, spread_after_1, per_shot * 100.0])
	# Очередь быстрее темпа восстановления доходит до потолка и не выше.
	_reset_weapon()
	_weapon.stats.automatic = true
	_weapon.stats.magazine_size = 200
	_weapon.ammo = 200
	_weapon.stats.fire_rate = maxf(per_shot * 30.0, 12.0) if per_shot > 0.0 else 12.0
	var fast_enough: bool = _weapon.stats.fire_rate * per_shot > _weapon.shooting.bloom_recovery
	Input.action_press("fire")
	await _frames(int(cap / maxf(_weapon.stats.fire_rate * per_shot - _weapon.shooting.bloom_recovery, 0.01) * 120.0) + 120)
	var spread_burst: float = _weapon.get_current_spread()
	Input.action_release("fire")
	_check(fast_enough and absf(spread_burst - spread_start * (1.0 + cap)) < spread_start * 0.05, "длинная очередь раскрывает разброс до потолка: %.2f° (кучность %.2f° x %.2f)" % [spread_burst, spread_start, 1.0 + cap])
	await _frames(int(cap / maxf(_weapon.shooting.bloom_recovery, 0.05) * 120.0) + 30)
	_check(is_equal_approx(_weapon.get_current_spread(), spread_start), "без стрельбы разброс возвращается к %.2f°" % spread_start)
	# Раскрытие зависит от кучности: у точного оружия градусов меньше, у неточного больше (в тех же долях).
	_reset_weapon()
	_weapon.stats.spread_deg = _real_spread * 2.0
	_weapon.set("_bloom", cap)
	_check(is_equal_approx(_weapon.get_current_spread(), _real_spread * 2.0 * (1.0 + cap)), "раскрытие пропорционально кучности: вдвое неточнее оружие, вдвое больше градусов")
	_weapon.stats.fire_rate = saved_rate
	_weapon.stats.automatic = saved_auto
	_weapon.stats.magazine_size = saved_mag
	_reset_weapon()
	_weapon.set("_bloom", 0.0)
	# Фактические выстрелы тоже не выходят за конус (проверка по сигналу).
	_reset_weapon()
	_shots.clear()
	var forward2: Vector3 = -_camera.global_basis.z
	var cone_ok: bool = true
	for i: int in 8:
		await _frames(40)
		_reset_weapon()
		var allowed: float = _weapon.get_current_spread()
		await _tap("fire")
		var angle2: float = rad_to_deg(forward2.angle_to(_shots.back()["dir"]))
		if angle2 > allowed + 0.001:
			cone_ok = false
	_check(cone_ok, "реальные выстрелы не выходят за текущий конус")

	print("--- Отдача")
	await _place(Vector3(0, 0.05, 12), 0.0)
	await _frames(120)
	_reset_weapon()
	var pitch_before: float = _camera.global_rotation.x
	await _tap("fire")
	var peak: float = 0.0
	var peak_frame: int = 0
	var rise_after_1: float = -1.0
	for i: int in 60:
		await physics_frame
		var rise: float = rad_to_deg(_camera.global_rotation.x - pitch_before)
		if i == 0:
			rise_after_1 = rise
		if rise > peak:
			peak = rise
			peak_frame = i
	_check(peak > _weapon.stats.recoil_deg * 0.45 and peak <= _weapon.stats.recoil_deg + 0.02, "выстрел поднимает камеру на %.2f° при номинале %.2f° (цель отдачи уже затухает, пока камера её догоняет)" % [peak, _weapon.stats.recoil_deg])
	_check(rise_after_1 < peak * 0.8 and peak_frame >= 3, "подъём мягкий, не мгновенный: через кадр %.2f° из пика %.2f°, пик на %.0f мс" % [rise_after_1, peak, peak_frame / 120.0 * 1000.0])
	await _frames(120)
	_check(absf(rad_to_deg(_camera.global_rotation.x - pitch_before)) < 0.05, "камера вернулась на место")
	_check(absf(_weapon.get_node("Viewmodel").position.z - _weapon.shooting.hip_position.z) < 0.005, "модель оружия вернулась на место")
	# Серия: отдача складывается, но не уходит в потолок.
	await _frames(40)
	_reset_weapon()
	_weapon.stats.spread_deg = 0.0
	var series_start: float = _camera.global_rotation.x
	var series_peak: float = 0.0
	for i: int in 4:
		await _tap("fire")
		for j: int in 26:
			await physics_frame
			series_peak = maxf(series_peak, rad_to_deg(_camera.global_rotation.x - series_start))
	_check(series_peak > peak * 1.1 and series_peak < _weapon.stats.recoil_deg * 4.0, "серия из 4 выстрелов: пик %.2f° (один выстрел %.2f°): отдача складывается и не уходит в потолок" % [series_peak, peak])
	await _frames(240)

	print("--- Перезарядка")
	await _frames(20)
	_reset_weapon()
	_weapon.ammo = 4
	await _tap("reload")
	_check(_weapon.is_reloading and _weapon.ammo == 4, "R: перезарядка пошла, патроны пока 4")
	var fired_state: Dictionary = {"n": 0}
	var count_fire: Callable = func(_r: float) -> void: fired_state["n"] += 1
	_weapon.fired.connect(count_fire)
	await _tap("fire")
	_weapon.fired.disconnect(count_fire)
	_check(fired_state["n"] == 0, "во время перезарядки стрелять нельзя")
	var reload_frames: int = 0
	while _weapon.is_reloading and reload_frames < 1200:
		await physics_frame
		reload_frames += 1
	_check(absf(reload_frames / 120.0 - _weapon.stats.reload_time) < 0.15 and _weapon.ammo == _weapon.stats.magazine_size, "перезарядка заняла %.2f с (по данным %.2f с), магазин полный" % [reload_frames / 120.0, _weapon.stats.reload_time])
	await _frames(10)
	await _tap("reload")
	_check(not _weapon.is_reloading, "полный магазин не перезаряжается")
	_weapon.ammo = 0
	var reload_state: Dictionary = {"started": false}
	var start_cb: Callable = func() -> void: reload_state["started"] = true
	_weapon.reload_started.connect(start_cb)
	var shots_before: int = _shots.size()
	await _tap("fire")
	_weapon.reload_started.disconnect(start_cb)
	_check(reload_state["started"] and _shots.size() == shots_before, "пустой магазин и огонь: автоперезарядка, выстрела нет")
	await _frames(int(_weapon.stats.reload_time * 120.0) + 40)
	_check(_weapon.ammo == _weapon.stats.magazine_size and not _weapon.is_reloading, "автоперезарядка завершилась")

	print("--- Прицеливание на ПКМ")
	await _place(Vector3(0, 0.05, 19), 0.0)
	_reset_weapon()
	var base_fov: float = _player.settings.field_of_view
	Input.action_press("aim")
	await _frames(int(_weapon.stats.aim_time * 0.5 * 120.0))
	_check(_weapon.aim_amount > 0.35 and _weapon.aim_amount < 0.7, "на половине времени входа (%.2f с) прицеливание на полпути: %.2f" % [_weapon.stats.aim_time * 0.5, _weapon.aim_amount])
	await _frames(int(_weapon.stats.aim_time * 120.0) + 10)
	_check(is_equal_approx(_weapon.aim_amount, 1.0), "прицеливание полностью включилось за ~0.15 с")
	var zoomed_fov: float = rad_to_deg(2.0 * atan(tan(deg_to_rad(base_fov) * 0.5) / _weapon.stats.aim_zoom))
	_check(absf(_camera.fov - zoomed_fov) < 0.2, "угол обзора %.1f° -> %.1f° (зум x%.1f, ждём %.1f°)" % [base_fov, _camera.fov, _weapon.stats.aim_zoom, zoomed_fov])
	_check(is_equal_approx(_weapon.get_zoom(), _weapon.stats.aim_zoom), "get_zoom() = %.2f (из данных корпуса)" % _weapon.get_zoom())
	_check(is_equal_approx(_weapon.get_current_spread(), _weapon.stats.spread_deg * _weapon.shooting.aim_spread_multiplier), "разброс при прицеливании %.2f°" % _weapon.get_current_spread())
	var anchor: Node3D = _weapon.get_node("Viewmodel/AimAnchor")
	var anchor_in_camera: Vector3 = _camera.to_local(anchor.global_position)
	_check(absf(anchor_in_camera.x) < 0.002 and absf(anchor_in_camera.y) < 0.002 and absf(anchor_in_camera.z + _weapon.shooting.aim_eye_distance) < 0.005, "прицел оружия (AimAnchor) встал в центр экрана: x=%.4f y=%.4f z=%.3f (глаз %.2f м)" % [anchor_in_camera.x, anchor_in_camera.y, anchor_in_camera.z, _weapon.shooting.aim_eye_distance])
	_check(_weapon.has_node("Viewmodel/RearSightLeft") and _weapon.has_node("Viewmodel/RearSightRight") and _weapon.has_node("Viewmodel/FrontSight"), "на модели есть целик (две стойки) и мушка")
	var aim_crosshair: Control = _room.get_node("Hud/Root/Crosshair")
	_check(is_equal_approx(aim_crosshair.get("_aim"), 1.0) and is_equal_approx(aim_crosshair.aiming_alpha, 0.0), "прицел-крест получает прицеливание и гаснет (aiming_alpha %.1f)" % aim_crosshair.aiming_alpha)
	Input.action_press("move_forward")
	await _frames(60)
	_check(absf(_player.get_horizontal_speed() - _player.movement.walk_speed) < 0.1, "прицеливание не замедляет ходьбу (%.2f м/с)" % _player.get_horizontal_speed())
	Input.action_press("sprint")
	await _frames(40)
	_check(absf(_player.get_horizontal_speed() - _player.movement.sprint_speed) < 0.1 and _weapon.aim_amount > 0.99, "и спринт не прерывает прицеливание (%.2f м/с)" % _player.get_horizontal_speed())
	Input.action_press("crouch")
	await _frames(10)
	_check(_player.state == S_SLIDE and _weapon.aim_amount > 0.99, "подкат не прерывает прицеливание")
	Input.action_release("crouch")
	Input.action_release("sprint")
	Input.action_release("move_forward")
	await _frames(40)
	# Перезарядка прерывает прицеливание и возвращает его, если ПКМ всё ещё зажата.
	_reset_weapon()
	_weapon.ammo = 5
	await _tap("reload")
	await _frames(30)
	_check(_weapon.is_reloading and _weapon.aim_amount < 0.01, "перезарядка прервала прицеливание (aim %.2f)" % _weapon.aim_amount)
	await _frames(int(_weapon.stats.reload_time * 120.0) + 40)
	_check(not _weapon.is_reloading and _weapon.aim_amount > 0.99, "после перезарядки ПКМ зажата, прицеливание вернулось")
	Input.action_release("aim")
	await _frames(40)
	_check(_weapon.aim_amount < 0.01 and absf(_camera.fov - base_fov) < 0.2, "отпустили ПКМ: вышли из прицеливания, FOV %.1f°" % _camera.fov)

	print("--- Ближний бой")
	var melee_damage: float = _player.get_node("Melee").settings.damage
	await _place(Vector3(0, 0.05, 4), 0.0)
	dummy.health = dummy_max
	await _tap("melee")
	_check(is_equal_approx(dummy.health, dummy_max - melee_damage), "удар V по мишени вплотную: %.0f -> %.0f (урон удара %.0f)" % [dummy_max, dummy.health, melee_damage])
	await _tap("melee")
	_check(is_equal_approx(dummy.health, dummy_max - melee_damage), "повторный удар до конца паузы не проходит")
	await _frames(90)
	await _place(Vector3(0, 0.05, 8), 0.0)
	var h0: float = dummy.health
	await _tap("melee")
	_check(is_equal_approx(dummy.health, h0), "мишень в 6 м удар не достаёт")
	await _frames(60)

	print("--- Мишень: полоска, гибель, возвращение")
	dummy.health = dummy_max
	dummy.call("_update_bar")
	dummy.take_hit(DamageInfo.create(dummy_max * 0.25, false, Vector3.ZERO))
	var fill: Node3D = dummy.get_node("HealthBar/Fill")
	_check(absf(fill.scale.x - 0.75) < 0.001 and absf(fill.position.x - (-0.125)) < 0.001, "полоска убывает справа налево: scale %.3f, сдвиг %.3f" % [fill.scale.x, fill.position.x])
	_check((dummy.get_node("HealthBar/Value") as Label3D).text == str(ceili(dummy_max * 0.75)), "число здоровья над мишенью: %s" % (dummy.get_node("HealthBar/Value") as Label3D).text)
	var killed: bool = dummy.take_hit(DamageInfo.create(dummy_max, false, Vector3.ZERO))
	await physics_frame
	_check(killed and dummy.is_dead and not dummy.visible and dummy.collision_layer == 0, "мишень уничтожена: скрыта и не принимает выстрелы")
	await _frames(int(dummy.settings.respawn_time * 120.0) + 20)
	_check(not dummy.is_dead and dummy.visible and dummy.collision_layer == 20 and is_equal_approx(dummy.health, dummy_max), "через %.0f с мишень вернулась с полным здоровьем" % dummy.settings.respawn_time)

	print("--- Игрок и мишени, хук")
	await _place(Vector3(0, 0.05, 8), 0.0)
	Input.action_press("move_forward")
	await _frames(90)
	Input.action_release("move_forward")
	_check(_player.global_position.z > 2.7 and _player.global_position.z < 3.3, "игрок упирается в мишень, не проходит сквозь (z=%.2f)" % _player.global_position.z)
	await _place(Vector3(0, 0.05, 12), -4.29)
	await _tap("hook")
	var target: Vector3 = _player.get_node("Hook").get("_target")
	_check(target.z < 0.0, "хук мишень не цепляет, луч проходит сквозь неё к полу за ней (z=%.1f, мишень на z=2)" % target.z)
	Input.action_release("hook")
	await _frames(10)
	_player.get_node("Hook").call("release")
	_player.state = S_AIR
	await _until_floor()

	print("--- HUD патронов и прицел")
	await _place(Vector3(0, 0.05, 12), 8.0)
	_reset_weapon()
	await _frames(5)
	var counter: Label = _room.get_node("Hud/Root/AmmoCounter")
	var arc: Control = _room.get_node("Hud/Root/Crosshair/AmmoArc")
	var crosshair: Control = _room.get_node("Hud/Root/Crosshair")
	var capacity: int = _weapon.stats.magazine_size
	_check(counter.text == "%d/%d" % [capacity, capacity], "счётчик справа снизу: %s" % counter.text)
	_check(arc.get("_ammo") == capacity and arc.get("_capacity") == capacity and arc.get("_reload_progress") < 0.0, "дуга патронов: %d из %d" % [capacity, capacity])
	await _tap("fire")
	await _frames(3)
	_check(counter.text == "%d/%d" % [capacity - 1, capacity] and arc.get("_ammo") == capacity - 1, "после выстрела: %s" % counter.text)
	_weapon.ammo = 3
	await _tap("reload")
	await _frames(40)
	_check(counter.text == tr("HUD_RELOADING") and counter.text == "Перезарядка" and arc.get("_reload_progress") > 0.1, "при перезарядке: «%s», прогресс дуги %.2f" % [counter.text, arc.get("_reload_progress")])
	await _frames(int(_weapon.stats.reload_time * 120.0) + 40)
	_check(counter.text == "%d/%d" % [capacity, capacity], "после перезарядки: %s" % counter.text)
	var gap_rest: float = crosshair.get("_extra_gap")
	Input.action_press("move_forward")
	Input.action_press("sprint")
	await _frames(80)
	var gap_sprint: float = crosshair.get("_extra_gap")
	_check(gap_rest > 0.0 and gap_sprint > gap_rest * 1.6, "прицел расходится вслед за разбросом: %.2f px в покое, %.2f px в спринте (x%.2f; в безоконном режиме вьюпорт крошечный)" % [gap_rest, gap_sprint, gap_sprint / gap_rest])
	_release_all()
	await _frames(60)
	await _place(Vector3(0, 0.05, 12), -4.29)
	_reset_weapon()
	_weapon.stats.spread_deg = 0.0
	dummy.health = dummy_max
	await _tap("fire")
	await _frames(2)
	_check(crosshair.get("_flash") > 0.2, "попадание по мишени: прицел вспыхивает")
	var overlay_text: String = (_room.get_node("DebugOverlay/Label") as Label).text
	print(overlay_text.replace("\n", " | "))
	_check(overlay_text.contains("Оружие: Заводской пистолет") and overlay_text.contains("разброс") and overlay_text.contains("прицел"), "отладочная надпись показывает оружие, патроны, разброс и прицел")


# Независимый расчёт характеристик: база корпуса и произведение множителей всех частей.
func _expected_stats(parts: Array) -> Dictionary:
	var body: WeaponPart = null
	for part: WeaponPart in parts:
		if part.part_type == WeaponPart.PartType.BODY:
			body = part
	var result: Dictionary = {
		"damage": body.base_damage, "fire_rate": body.base_fire_rate, "automatic": body.automatic,
		"magazine": float(body.base_magazine_size), "reload": body.base_reload_time,
		"spread": body.base_spread_deg, "range": body.base_range, "recoil": body.base_recoil_deg,
		"aim_time": body.base_aim_time, "zoom": body.aim_zoom,
	}
	for part: WeaponPart in parts:
		result["damage"] *= part.damage_mult
		result["fire_rate"] *= part.fire_rate_mult
		result["magazine"] *= part.magazine_size_mult
		result["reload"] *= part.reload_time_mult
		result["spread"] *= part.spread_mult
		result["range"] *= part.range_mult
		result["recoil"] *= part.recoil_mult
		result["aim_time"] *= part.aim_time_mult
	result["magazine"] = maxi(1, roundi(result["magazine"]))
	return result


func _until_floor() -> void:
	for i: int in 400:
		if _player.is_on_floor():
			return
		await physics_frame
