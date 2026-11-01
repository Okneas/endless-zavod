@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: меню паузы по Esc, настройки, масштаб меню и его сохранение (№79).
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_menu.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.

const TEST_FILE: String = "user://test_settings.cfg"

var _fails: int = 0
var _room: Node
var _hud: Node
var _pause
var _settings
var _config
var _player


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _esc() -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = KEY_ESCAPE
	event.keycode = KEY_ESCAPE
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await _frames(3)


func _initialize() -> void:
	create_timer(300.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	_settings = root.get_node("UserSettings")
	_config = root.get_node("Config")
	_settings.config_path = TEST_FILE
	if FileAccess.file_exists(TEST_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_FILE))
	_settings.load_settings()
	_room = (load("res://rooms/test_room.tscn") as PackedScene).instantiate()
	_room.get_node("Enemies").free()
	root.add_child(_room)
	await _frames(10)
	_hud = _room.get_node("Hud")
	_player = _room.get_node("Player")
	for child: Node in _hud.get_children():
		var script: Script = child.get_script()
		if script != null and script.get_global_name() == "PauseMenu":
			_pause = child
	_test_data()
	await _test_settings()
	await _test_pause_flow()
	await _test_inventory_scale()
	if FileAccess.file_exists(TEST_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_FILE))
	print("=== FAILS: ", _fails)
	quit(_fails)


func _test_data() -> void:
	print("--- Данные")
	var menus: MenuSettings = _config.data.menus
	var steps: PackedFloat32Array = menus.scale_steps
	var sorted_ok: bool = steps.size() >= 2
	for i: int in range(1, steps.size()):
		if steps[i] <= steps[i - 1]:
			sorted_ok = false
	_check(menus != null and sorted_ok and steps.has(menus.default_scale), "ступени масштаба меню по возрастанию %s, стартовое значение %.2f среди них" % [str(steps), menus.default_scale])
	_check(steps.has(1.0) and steps[0] <= 0.25 + 0.001, "есть ступень 1 (эталон) и самая мелкая не больше 0.25")
	var missing: PackedStringArray = []
	for key: String in ["PAUSE_TITLE", "PAUSE_RESUME", "PAUSE_SETTINGS", "PAUSE_QUIT", "SETTINGS_TITLE", "SETTINGS_MENU_SCALE", "SETTINGS_MENU_SCALE_NOTE", "SETTINGS_BACK"]:
		if tr(key) == key:
			missing.append(key)
	_check(missing.is_empty(), "строки меню паузы и настроек есть в таблице переводов %s" % str(missing))
	_check(_pause != null, "меню паузы создано в HUD")


func _test_settings() -> void:
	print("--- Настройки игрока и масштаб меню")
	var menus: MenuSettings = _config.data.menus
	_check(is_equal_approx(_settings.menu_scale, menus.default_scale), "без файла масштаб меню равен значению по умолчанию %.2f" % menus.default_scale)
	_check(is_equal_approx(root.content_scale_factor, 1.0), "вне меню окно не растянуто сверх эталона (%.2f)" % root.content_scale_factor)
	_settings.enter_menu()
	_check(is_equal_approx(root.content_scale_factor, _settings.menu_scale), "меню открылось: окно растянуто на масштаб меню (%.2f)" % root.content_scale_factor)
	_settings.enter_menu()
	_settings.leave_menu()
	_check(is_equal_approx(root.content_scale_factor, _settings.menu_scale), "вложенное меню: пока открыто хоть одно, масштаб остаётся")
	_settings.leave_menu()
	_check(is_equal_approx(root.content_scale_factor, 1.0), "все меню закрыты: масштаб вернулся к 1")
	_settings.leave_menu()
	_check(is_equal_approx(root.content_scale_factor, 1.0), "лишний вызов закрытия счётчик не ломает")
	var emitted: Dictionary = {"count": 0}
	_settings.menu_scale_changed.connect(func(_value: float) -> void: emitted["count"] += 1)
	var steps: PackedFloat32Array = menus.scale_steps
	var chosen: float = steps[steps.size() - 1]
	_settings.set_menu_scale(chosen)
	_check(is_equal_approx(_settings.menu_scale, chosen) and emitted["count"] == 1 and FileAccess.file_exists(TEST_FILE), "выбор ступени %.2f запомнен в файле, сигнал пришёл" % chosen)
	_settings.menu_scale = 1.0
	_settings.load_settings()
	_check(is_equal_approx(_settings.menu_scale, chosen), "после перезагрузки настроек масштаб прежний (%.2f)" % _settings.menu_scale)
	_settings.set_menu_scale(steps[0] + 0.01)
	_check(is_equal_approx(_settings.menu_scale, steps[0]), "значение между ступенями округляется до ближайшей (%.2f)" % _settings.menu_scale)
	_settings.set_menu_scale(menus.default_scale)


func _test_pause_flow() -> void:
	print("--- Меню паузы")
	var resume: Button = _pause.get("_resume_button")
	var settings_button: Button = _pause.get("_settings_button")
	var back: Button = _pause.get("_back_button")
	var option: OptionButton = _pause.get("_scale_option")
	_check(not _pause.is_open() and not _pause.visible and not paused, "по умолчанию пауза закрыта, игра идёт")
	await _esc()
	_check(_pause.is_open() and _pause.visible and paused, "Esc открыл меню паузы, игра на паузе")
	_check(is_equal_approx(root.content_scale_factor, _settings.menu_scale), "пока пауза открыта, окно растянуто на масштаб меню")
	_check(resume.text == tr("PAUSE_RESUME") and settings_button.text == tr("PAUSE_SETTINGS") and _pause.get("_quit_button").text == tr("PAUSE_QUIT"), "в меню три пункта: «%s», «%s», «%s»" % [resume.text, settings_button.text, _pause.get("_quit_button").text])
	_check(not _pause.is_settings_page(), "открывается главная страница меню, не настройки")
	settings_button.pressed.emit()
	_check(_pause.is_settings_page() and back.is_visible_in_tree() and option.is_visible_in_tree(), "«Настройки» открыли страницу с выбором масштаба")
	var steps: PackedFloat32Array = _config.data.menus.scale_steps
	_check(option.item_count == steps.size() and option.selected == steps.find(_settings.menu_scale), "в списке %d ступеней, выбрана текущая" % option.item_count)
	var texts: PackedStringArray = []
	for i: int in option.item_count:
		texts.append(option.get_item_text(i))
	_check(texts[steps.find(1.0)] == "1×" and texts[0] == "%s×" % String.num(steps[0]), "подписи ступеней: %s" % str(texts))
	var target: int = 0 if steps.find(_settings.menu_scale) != 0 else 1
	option.select(target)
	option.item_selected.emit(target)
	_check(is_equal_approx(_settings.menu_scale, steps[target]) and is_equal_approx(root.content_scale_factor, steps[target]), "выбор ступени %.2f сразу меняет масштаб открытого меню" % steps[target])
	await _esc()
	_check(_pause.is_open() and not _pause.is_settings_page(), "Esc в настройках возвращает в меню паузы, не закрывая его")
	settings_button.pressed.emit()
	back.pressed.emit()
	_check(_pause.is_open() and not _pause.is_settings_page(), "«Назад» возвращает в меню паузы")
	await _esc()
	_check(not _pause.is_open() and not paused and is_equal_approx(root.content_scale_factor, 1.0), "Esc в меню паузы закрыл его: игра идёт, масштаб вернулся к 1")
	await _esc()
	resume.pressed.emit()
	_check(not _pause.is_open() and not paused and is_equal_approx(root.content_scale_factor, 1.0), "«Продолжить» закрывает паузу")
	_settings.set_menu_scale(_config.data.menus.default_scale)


func _test_inventory_scale() -> void:
	print("--- Масштаб меню в инвентаре и Esc")
	var screen = _hud.get_node("InventoryScreen")
	Input.action_press("inventory_toggle")
	await _frames(3)
	Input.action_release("inventory_toggle")
	await _frames(3)
	_check(screen.is_open() and is_equal_approx(root.content_scale_factor, _settings.menu_scale), "инвентарь открыт: окно растянуто на масштаб меню (%.2f)" % root.content_scale_factor)
	var steps: PackedFloat32Array = _config.data.menus.scale_steps
	var visible_before: Vector2 = root.get_visible_rect().size
	var before_scale: float = _settings.menu_scale
	var other: float = steps[0] if not is_equal_approx(_settings.menu_scale, steps[0]) else steps[steps.size() - 1]
	_settings.set_menu_scale(other)
	await _frames(3)
	var visible_after: Vector2 = root.get_visible_rect().size
	_check(is_equal_approx(root.content_scale_factor, other) and absf(visible_before.x * before_scale / other - visible_after.x) < 2.0, "смена масштаба при открытом инвентаре применяется сразу: видимая область %s -> %s" % [str(visible_before), str(visible_after)])
	await _esc()
	_check(not screen.is_open() and not _pause.is_open() and not paused and is_equal_approx(root.content_scale_factor, 1.0), "Esc при открытом инвентаре закрывает только инвентарь, масштаб вернулся к 1")
	_settings.set_menu_scale(_config.data.menus.default_scale)
	_player.take_damage(1000.0)
	await _frames(3)
	await _esc()
	_check(not _pause.is_open() and not paused, "мёртвому игроку Esc паузу не открывает")

