class_name ModalPanel
extends CanvasLayer
## Основа модальных панелей забега (срез 7): панель эвакуации, экран итогов. Затемнение, колонка по центру, тема меню.
## Пока панель открыта, игра на паузе, мышь свободна, масштаб меню как у паузы (UserSettings). Esc вызывает _on_cancel().
## Размеры в единицах эталона 1920 x 1080 (№78).

signal opened
signal closed

const FONT_SIZE: int = 30
const TITLE_SIZE: int = 60
const COLUMN_WIDTH: float = 820.0
const BUTTON_HEIGHT: float = 84.0

var column: VBoxContainer
var _is_open: bool = false


func _ready() -> void:
	layer = 35
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var root: Control = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = MenuTheme.build(FONT_SIZE)
	add_child(root)
	var dim: ColorRect = ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.78)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)
	column = VBoxContainer.new()
	column.custom_minimum_size.x = COLUMN_WIDTH
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)


func is_open() -> bool:
	return _is_open


func _unhandled_input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed(&"ui_cancel"):
		_on_cancel()
		get_viewport().set_input_as_handled()


## Показывает панель: игра на паузе, мышь свободна. Содержимое колонки собирает вызывающий код до этого.
func open() -> void:
	if _is_open:
		return
	_is_open = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = true
	UserSettings.enter_menu()
	visible = true
	opened.emit()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	visible = false
	get_tree().paused = false
	UserSettings.leave_menu()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


## Esc по умолчанию закрывает панель; наследники переопределяют (экран итогов не закрывается Esc).
func _on_cancel() -> void:
	close()


func clear_column() -> void:
	for child: Node in column.get_children():
		column.remove_child(child)
		child.queue_free()


func add_title(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", TITLE_SIZE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	return label


func add_line(text: String, color: Color = Color.WHITE) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = COLUMN_WIDTH
	column.add_child(label)
	return label


func add_button(text: String, action: Callable, enabled: bool = true) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0.0, BUTTON_HEIGHT)
	button.disabled = not enabled
	button.pressed.connect(action)
	column.add_child(button)
	return button
