extends Control
## Подсказка в правом верхнем углу HUD: рамка с названием клавиши инвентаря и значком списка (набросок автора, 11-UI-design).
## Название клавиши берётся из InputMap, поэтому следует за переназначением.

@export var action: StringName = &"inventory_toggle"


func _draw() -> void:
	var frame: Rect2 = Rect2(Vector2.ZERO, size)
	draw_rect(frame, Color(0.06, 0.06, 0.08, 0.7))
	draw_rect(frame.grow(-1.0), Color(1.0, 1.0, 1.0, 0.6), false, 2.0)
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(10.0, size.y * 0.5 + 6.0), _key_name(), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color.WHITE)
	# Значок списка: три строки.
	var x: float = size.x - 30.0
	for i: int in 3:
		var y: float = size.y * 0.5 - 8.0 + float(i) * 8.0
		draw_rect(Rect2(x, y, 4.0, 3.0), Color.WHITE)
		draw_rect(Rect2(x + 8.0, y, 14.0, 3.0), Color.WHITE)


func _key_name() -> String:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if events.is_empty():
		return "?"
	var key: InputEventKey = events[0] as InputEventKey
	if key != null:
		return OS.get_keycode_string(key.physical_keycode)
	return events[0].as_text()
