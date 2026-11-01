@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Отладочные инструменты (срез 9, №89): панель по F1 (открывается и закрывается, ставит игру на паузу, не открывается поверх другого
## окна), выдача денег, оружия, детали и предмета, переключение дня и ночи, уровень персонажа и мира, сид зон, кнопки панели.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_debug_tools.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.

var _fails: int = 0
var _tools
var _progress
var _inventory
var _clock
var _hub


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


# Кнопка панели по тексту (поиск по всему дереву панели).
func _button(text: String) -> Button:
	for button in _tools.panel.find_children("*", "Button", true, false):
		if button.text == text:
			return button
	return null


# Сколько всего штук в рюкзаке (расходники лежат стопками).
func _total_count() -> int:
	var total: int = 0
	for item in _inventory.items:
		total += item.count
	return total


func _initialize() -> void:
	create_timer(300.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	var config = root.get_node("Config")
	_tools = root.get_node("DebugTools")
	_progress = root.get_node("Progress")
	_inventory = root.get_node("Inventory")
	_clock = root.get_node("GameClock")
	var shop = root.get_node("Shop")
	_progress.reset()
	_inventory.clear()
	shop.reset()
	root.size = Vector2i(1920, 1080)
	_hub = (load("res://hub/hub.tscn") as PackedScene).instantiate()
	root.add_child(_hub)
	await _frames(10)
	var seed_before: int = config.data.zones.debug_seed
	var world_before: int = _progress.world_level

	print("--- Панель F1")
	var f1: Array = InputMap.action_get_events(&"debug_panel")
	_check(f1.size() == 1 and f1[0] is InputEventKey and f1[0].physical_keycode == KEY_F1, "действие debug_panel стоит на F1")
	_check(_tools.panel != null and not _tools.panel.is_open(), "панель есть и закрыта")
	var press: InputEventAction = InputEventAction.new()
	press.action = &"debug_panel"
	press.pressed = true
	Input.parse_input_event(press)
	await _frames(3)
	_check(_tools.panel.is_open() and paused, "F1 открыла панель, игра на паузе")
	var release: InputEventAction = InputEventAction.new()
	release.action = &"debug_panel"
	release.pressed = false
	Input.parse_input_event(release)
	await _frames(2)
	_tools.toggle_panel()
	await _frames(2)
	_check(not _tools.panel.is_open() and not paused, "повторный вызов закрыл панель, пауза снята")
	# Поверх другого окна панель не открывается.
	_hub.trader_panel.present()
	await _frames(2)
	_tools.toggle_panel()
	_check(not _tools.panel.is_open() and _hub.trader_panel.is_open(), "пока открыто окно торговца, панель не открывается поверх")
	_hub.trader_panel.close()
	await _frames(2)

	print("--- Действия")
	_tools.toggle_panel()
	await _frames(2)
	var money: int = _progress.money
	_button(tr("DBG_MONEY").format({"amount": 1000})).pressed.emit()
	_check(_progress.money == money + 1000, "кнопка «+1000 монет»: %d -> %d" % [money, _progress.money])
	_check(_tools.panel.find_children("*", "Label", true, false).any(func(label) -> bool: return label.text.contains(str(_progress.money))), "строка состояния показывает новые деньги")
	var count: int = _inventory.items.size()
	_button(tr("DBG_GIVE_WEAPON")).pressed.emit()
	_check(_inventory.items.size() == count + 1 and _inventory.items[count].weapon != null and _inventory.items[count].weapon.level == _progress.level, "«Выдать оружие»: оружие уровня персонажа (%d) в рюкзаке" % _progress.level)
	_button(tr("DBG_GIVE_PART")).pressed.emit()
	_check(_inventory.items.size() == count + 2 and _inventory.items[count + 1].part != null, "«Выдать деталь»: деталь в рюкзаке")
	_button(tr("DBG_GIVE_ITEM")).pressed.emit()
	_check(_inventory.items.size() == count + 3 and _inventory.items[count + 2].weapon == null and _inventory.items[count + 2].part == null, "«Выдать предмет»: расходник в рюкзаке")
	var was_night: bool = _clock.is_night
	var phase_events: Array = []
	_clock.phase_changed.connect(func(night: bool) -> void: phase_events.append(night))
	_button(tr("DBG_PHASE_NIGHT")).pressed.emit()
	_check(_clock.is_night and phase_events == [true] and _button(tr("DBG_PHASE_NIGHT")).disabled, "«Сделать ночь»: ночь, сигнал фазы пришёл, кнопка недоступна")
	_button(tr("DBG_PHASE_DAY")).pressed.emit()
	_check(not _clock.is_night and phase_events == [true, false] and _clock.time_in_cycle == 0.0, "«Сделать день»: день с начала, сигнал фазы пришёл")
	var level: int = _progress.level
	_button(tr("DBG_LEVEL_UP")).pressed.emit()
	_check(_progress.level == level + 1, "«+1 уровень персонажа»: %d -> %d" % [level, _progress.level])
	var world_step: int = _tools.panel.WORLD_STEP
	_button("+%d" % world_step).pressed.emit()
	_check(_progress.world_level == world_before + world_step, "уровень мира +%d: %d -> %d" % [world_step, world_before, _progress.world_level])
	for i: int in 40:
		_button("-%d" % world_step).pressed.emit()
	_check(_progress.world_level == 1, "уровень мира не уходит ниже 1")
	for i: int in 400:
		_button("+%d" % world_step).pressed.emit()
	_check(_progress.world_level == config.data.run.world_level_max, "и не выше предела %d" % config.data.run.world_level_max)
	_progress.set_world_level(world_before)
	var spin: SpinBox = _tools.panel.find_children("*", "SpinBox", true, false)[0]
	spin.value = 12345.0
	_check(config.data.zones.debug_seed == 12345, "поле сида: сид зон %d" % config.data.zones.debug_seed)
	spin.value = 0.0
	_check(config.data.zones.debug_seed == 0, "сид 0: случайный")
	_tools.toggle_panel()
	await _frames(2)
	_check(not _tools.panel.is_open(), "панель закрыта")

	print("--- Выдача клавишами G и T")
	count = _inventory.items.size()
	var total: int = _total_count()
	Input.action_press(&"debug_give_weapon")
	await _frames(3)
	Input.action_release(&"debug_give_weapon")
	await _frames(2)
	_check(_inventory.items.size() == count + 1 and _inventory.items[count].weapon != null, "G кладёт оружие в рюкзак (теперь через DebugTools)")
	Input.action_press(&"debug_give_item")
	await _frames(3)
	Input.action_release(&"debug_give_item")
	await _frames(2)
	_check(_total_count() == total + 2, "T кладёт предмет в рюкзак (расходник доливается в стопку): всего %d -> %d" % [total, _total_count()])

	config.data.zones.debug_seed = seed_before
	_inventory.clear()
	shop.reset()
	print("=== FAILS: ", _fails)
	quit(_fails)
