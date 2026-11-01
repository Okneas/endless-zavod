extends Node
## Настройки игрока, которые запоминаются между запусками (файл user://settings.cfg). Сейчас это масштаб меню (№79).
## Масштаб действует только пока открыто меню (инвентарь, пауза): окно растягивается ещё на этот множитель
## (Window.content_scale_factor), текст остаётся чётким. HUD в забеге не меняется.

signal menu_scale_changed(value: float)

## Путь файла. Тесты подставляют свой, чтобы не трогать настройки игрока.
var config_path: String = "user://settings.cfg"
var menu_scale: float = 1.0

var _menu_depth: int = 0


func _ready() -> void:
	load_settings()


## Читает файл настроек, без файла берётся значение по умолчанию из MenuSettings.
func load_settings() -> void:
	var value: float = Config.data.menus.default_scale
	var file: ConfigFile = ConfigFile.new()
	if file.load(config_path) == OK:
		value = float(file.get_value("menus", "scale", value))
	menu_scale = _snap(value)
	_apply()


func get_steps() -> PackedFloat32Array:
	return Config.data.menus.scale_steps


## Выбрать масштаб: ближайшая ступень, запись в файл, применение, если меню открыто.
func set_menu_scale(value: float) -> void:
	menu_scale = _snap(value)
	var file: ConfigFile = ConfigFile.new()
	file.load(config_path)
	file.set_value("menus", "scale", menu_scale)
	file.save(config_path)
	_apply()
	menu_scale_changed.emit(menu_scale)


## Меню открылось: окно растягивается на масштаб меню. Счётчик, потому что меню могут открываться друг из друга.
func enter_menu() -> void:
	_menu_depth += 1
	_apply()


func leave_menu() -> void:
	_menu_depth = maxi(_menu_depth - 1, 0)
	_apply()


func _apply() -> void:
	var window: Window = get_window()
	if window != null:
		window.content_scale_factor = menu_scale if _menu_depth > 0 else 1.0


# Ближайшая ступень из настроек (без ступеней значение просто ограничивается).
func _snap(value: float) -> float:
	var steps: PackedFloat32Array = get_steps()
	if steps.is_empty():
		return clampf(value, 0.25, 4.0)
	var best: float = steps[0]
	for step: float in steps:
		if absf(step - value) < absf(best - value):
			best = step
	return best
