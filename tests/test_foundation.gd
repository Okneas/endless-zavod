@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: основа проекта: игровые часы, конфиг, действия ввода, переводы.
## Запуск: godot --headless --path <проект> --script res://tests/test_foundation.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres) и InputMap, поэтому правки чисел и клавиш не ломают тест.

## Действия, которые код игры использует (имена, не клавиши: клавиши автор может менять).
const REQUIRED_ACTIONS: Array[String] = [
	"move_forward", "move_back", "move_left", "move_right", "jump", "sprint", "crouch", "hook",
	"fire", "aim", "reload", "melee", "interact", "weapon_slot_1", "weapon_slot_2", "weapon_slot_3",
	"weapon_slot_4", "weapon_next", "weapon_prev", "inventory_toggle",
]
## Строки перевода, которые обязаны существовать (ключ -> часть, которой не должно быть в переводе).
const REQUIRED_KEYS: Array[String] = ["DEBUG_PHASE_DAY", "DEBUG_PHASE_NIGHT", "DEBUG_CLOCK", "HUD_HP", "HUD_RELOADING", "WEAPON_STARTER_PISTOL"]

var _fails: int = 0
var _phase_events: Array = []
var _day_events: Array = []


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _initialize() -> void:
	create_timer(60.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	await _run()
	print("=== FAILS: ", _fails)
	quit(_fails)


func _run() -> void:
	var clock: Node = root.get_node("GameClock")
	var config: Node = root.get_node("Config")

	print("--- Config")
	_check(config.data != null and config.data.clock != null, "Config.data и часы загружены")
	var day: float = config.data.clock.day_duration_seconds
	var night: float = config.data.clock.night_duration_seconds
	var cycle: float = day + night
	_check(day > 0.0 and night > 0.0, "длительности дня %.0f с и ночи %.0f с положительные" % [day, night])
	var saved_offset: float = config.data.clock.start_offset_seconds

	print("--- GameClock: границы фаз")
	config.data.clock.start_offset_seconds = 0.0
	clock.phase_changed.connect(func(is_night: bool) -> void: _phase_events.append(is_night))
	clock.day_started.connect(func(day_index: int) -> void: _day_events.append(day_index))
	clock.reset()
	_check(clock.day_index == 1 and not clock.is_night and is_equal_approx(clock.time_in_cycle, 0.0), "reset: сутки 1, день, t=0")
	clock.advance(day - 1.0)
	_check(not clock.is_night and _phase_events.is_empty(), "за секунду до конца дня: ещё день, сигналов нет")
	clock.advance(1.0)
	_check(clock.is_night and _phase_events == [true], "конец дня: наступила ночь, один сигнал phase_changed(true)")
	clock.advance(night - 1.0)
	_check(clock.is_night and clock.day_index == 1 and _day_events.is_empty(), "за секунду до конца суток: ещё ночь, новых суток нет")
	clock.advance(1.0)
	_check(not clock.is_night and clock.day_index == 2 and is_equal_approx(clock.time_in_cycle, 0.0), "конец суток: сутки 2, день, t=0")
	_check(_phase_events == [true, false] and _day_events == [2], "сигналы: phase [ночь, день], day_started [2]")

	print("--- GameClock: большой шаг через несколько границ")
	_phase_events.clear()
	_day_events.clear()
	clock.advance(cycle * 2.0 + day + 10.0)
	# С начала суток 2: два полных цикла и ещё день плюс 10 секунд ночи -> сутки 4, ночь, t = день + 10.
	_check(clock.day_index == 4 and clock.is_night and is_equal_approx(clock.time_in_cycle, day + 10.0), "два цикла и день с запасом: сутки 4, ночь, t=день+10 (t=%.1f)" % clock.time_in_cycle)
	_check(_phase_events == [true, false, true, false, true] and _day_events == [3, 4], "сигналы по каждой границе: phase %s, day %s" % [str(_phase_events), str(_day_events)])

	print("--- GameClock: смещение старта")
	config.data.clock.start_offset_seconds = day + 10.0
	clock.reset()
	_check(clock.is_night and is_equal_approx(clock.time_in_cycle, day + 10.0), "смещение за границу дня: старт ночью")
	config.data.clock.start_offset_seconds = cycle + 100.0
	clock.reset()
	_check(not clock.is_night and is_equal_approx(clock.time_in_cycle, 100.0), "смещение больше суток оборачивается: t=100, день")
	config.data.clock.start_offset_seconds = saved_offset
	clock.reset()

	print("--- GameClock: пауза дерева")
	await create_timer(0.2).timeout
	var running_t: float = clock.time_in_cycle
	_check(running_t > 0.0, "без паузы время идёт само (t=%.3f)" % running_t)
	paused = true
	var t_at_pause: float = clock.time_in_cycle
	await create_timer(0.3, true).timeout
	_check(is_equal_approx(clock.time_in_cycle, t_at_pause), "на паузе время стоит (t=%.3f)" % clock.time_in_cycle)
	paused = false
	await create_timer(0.2).timeout
	_check(clock.time_in_cycle > t_at_pause, "после снятия паузы время снова идёт")
	clock.reset()

	print("--- InputMap")
	for action_name: String in REQUIRED_ACTIONS:
		_check(InputMap.has_action(action_name) and InputMap.action_get_events(action_name).size() >= 1, "действие %s заведено и привязано" % action_name)
	_check(not InputMap.has_action("slide"), "отдельного действия slide нет (подкат на crouch)")

	print("--- Срабатывание событий")
	# Берём привязку из самой InputMap: тест не зависит от того, на какие клавиши автор переназначит действия.
	var bound: InputEventKey = InputMap.action_get_events("move_forward")[0] as InputEventKey
	var as_typed := InputEventKey.new()
	as_typed.device = 16
	as_typed.physical_keycode = bound.physical_keycode
	as_typed.keycode = bound.physical_keycode
	as_typed.pressed = true
	_check(InputMap.event_is_action(as_typed, "move_forward"), "физическая клавиша move_forward срабатывает")
	var other_layout := InputEventKey.new()
	other_layout.device = 16
	other_layout.physical_keycode = bound.physical_keycode
	other_layout.keycode = 0x0446 # «ц» на русской раскладке
	other_layout.pressed = true
	_check(InputMap.event_is_action(other_layout, "move_forward"), "та же клавиша при русской раскладке всё равно move_forward")
	_check(not InputMap.event_is_action(other_layout, "move_back"), "и не срабатывает как move_back")

	print("--- Переводы")
	var saved_locale: String = TranslationServer.get_locale()
	for locale: String in ["ru", "en", "de"]:
		TranslationServer.set_locale(locale)
		var all_translated: bool = true
		for key: String in REQUIRED_KEYS:
			if tr(key) == key:
				all_translated = false
		_check(all_translated, "локаль %s: все обязательные строки переведены (fallback на русский)" % locale)
	TranslationServer.set_locale(saved_locale)
	_check(tr("DEBUG_CLOCK").contains("{day}") and not tr("DEBUG_CLOCK").format({"day": 3, "phase": "x", "time": "5:07"}).contains("{day}"), "строка с подстановкой {day} форматируется")
