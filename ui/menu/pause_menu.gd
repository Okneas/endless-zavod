class_name PauseMenu
extends CanvasLayer
## Меню паузы по Esc (№79): «Продолжить», «Настройки», «Выйти из игры». В настройках выбор масштаба меню (ступени и
## значение по умолчанию в MenuSettings, выбор запоминает UserSettings). Пока меню открыто, игра на паузе, мышь свободна,
## окно растянуто на масштаб меню. Esc открывает паузу в HUD, а в самой паузе возвращает из настроек и закрывает её.
## Раскладка собирается кодом, размеры в единицах эталона 1920 x 1080.

signal opened
signal closed

const FONT_SIZE: int = 30
const TITLE_SIZE: int = 64
const COLUMN_WIDTH: float = 560.0
const BUTTON_HEIGHT: float = 84.0

var _is_open: bool = false
var _settings_page: bool = false
var _main_page: VBoxContainer
var _settings_box: VBoxContainer
var _scale_option: OptionButton
var _resume_button: Button
var _settings_button: Button
var _quit_button: Button
var _back_button: Button


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = MenuTheme.build(FONT_SIZE)
	add_child(root)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	var column: VBoxContainer = VBoxContainer.new()
	column.custom_minimum_size.x = COLUMN_WIDTH
	column.add_theme_constant_override("separation", 20)
	center.add_child(column)

	_main_page = VBoxContainer.new()
	_main_page.add_theme_constant_override("separation", 20)
	column.add_child(_main_page)
	_main_page.add_child(_title(tr("PAUSE_TITLE")))
	_resume_button = _button(_main_page, tr("PAUSE_RESUME"), close)
	_settings_button = _button(_main_page, tr("PAUSE_SETTINGS"), _show_settings)
	_quit_button = _button(_main_page, tr("PAUSE_QUIT"), get_tree().quit)

	_settings_box = VBoxContainer.new()
	_settings_box.add_theme_constant_override("separation", 20)
	column.add_child(_settings_box)
	_settings_box.add_child(_title(tr("SETTINGS_TITLE")))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	_settings_box.add_child(row)
	var caption: Label = Label.new()
	caption.text = tr("SETTINGS_MENU_SCALE")
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(caption)
	_scale_option = OptionButton.new()
	_scale_option.focus_mode = Control.FOCUS_NONE
	_scale_option.custom_minimum_size = Vector2(190.0, 0.0)
	row.add_child(_scale_option)
	var note: Label = Label.new()
	note.text = tr("SETTINGS_MENU_SCALE_NOTE")
	note.add_theme_font_size_override("font_size", 22)
	note.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.6))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = COLUMN_WIDTH
	_settings_box.add_child(note)
	_back_button = _button(_settings_box, tr("SETTINGS_BACK"), back)
	_fill_scale_options()
	_scale_option.item_selected.connect(_on_scale_selected)
	UserSettings.menu_scale_changed.connect(func(_value: float) -> void: _select_current_scale())
	_show_main()


func is_open() -> bool:
	return _is_open


func _unhandled_input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed(&"ui_cancel"):
		back()
		get_viewport().set_input_as_handled()


func is_settings_page() -> bool:
	return _settings_page


func open() -> void:
	if _is_open:
		return
	_is_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	UserSettings.enter_menu()
	_show_main()
	visible = true
	opened.emit()


## Закрыть меню и вернуться в игру: пауза снимается, мышь захватывается.
func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	get_tree().paused = false
	UserSettings.leave_menu()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


## Esc: из настроек в главное меню паузы, из него обратно в игру.
func back() -> void:
	if _settings_page:
		_show_main()
	else:
		close()


func _show_main() -> void:
	_settings_page = false
	_main_page.visible = true
	_settings_box.visible = false


func _show_settings() -> void:
	_settings_page = true
	_main_page.visible = false
	_settings_box.visible = true
	_select_current_scale()


func _fill_scale_options() -> void:
	_scale_option.clear()
	for step: float in UserSettings.get_steps():
		_scale_option.add_item("%s×" % _scale_text(step))
	_select_current_scale()


func _select_current_scale() -> void:
	var steps: PackedFloat32Array = UserSettings.get_steps()
	for i: int in steps.size():
		if is_equal_approx(steps[i], UserSettings.menu_scale):
			_scale_option.select(i)


func _on_scale_selected(index: int) -> void:
	UserSettings.set_menu_scale(UserSettings.get_steps()[index])


# 0.75 -> «0.75», 1.0 -> «1», 2.0 -> «2».
func _scale_text(value: float) -> String:
	return str(roundi(value)) if is_equal_approx(value, roundf(value)) else String.num(value)


func _title(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", TITLE_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


func _button(parent: Control, text: String, action: Callable) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	button.pressed.connect(action)
	parent.add_child(button)
	return button
