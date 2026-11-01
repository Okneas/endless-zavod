extends VBoxContainer
## Уведомления о подборе слева от центра, не больше трёх строк (11-UI-design, №50).
## Новая строка добавляется снизу, старые выше, каждая гаснет сама.

const MAX_LINES: int = 3
const LINE_LIFETIME: float = 2.6
const FADE_TIME: float = 0.5
const FONT_SIZE: int = 22


func add_line(text: String, color: Color = Color.WHITE) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	add_child(label)
	while get_child_count() > MAX_LINES:
		var oldest: Node = get_child(0)
		remove_child(oldest)
		oldest.queue_free()
	var tween: Tween = label.create_tween()
	tween.tween_interval(LINE_LIFETIME)
	tween.tween_property(label, "modulate:a", 0.0, FADE_TIME)
	tween.tween_callback(label.queue_free)
