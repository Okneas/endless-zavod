class_name KeyHint
extends RefCounted
## Название клавиши или кнопки мыши, назначенной на действие InputMap (первое событие действия).
## Подсказки клавиш на карточке и в экране инвентаря следуют за переназначением.


static func text(action: StringName) -> String:
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	if events.is_empty():
		return "?"
	var key: InputEventKey = events[0] as InputEventKey
	if key != null:
		var code: Key = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return OS.get_keycode_string(code)
	var mouse: InputEventMouseButton = events[0] as InputEventMouseButton
	if mouse != null:
		match mouse.button_index:
			MOUSE_BUTTON_LEFT:
				return TranslationServer.translate("INV_KEY_LMB")
			MOUSE_BUTTON_RIGHT:
				return TranslationServer.translate("INV_KEY_RMB")
			MOUSE_BUTTON_MIDDLE:
				return TranslationServer.translate("INV_KEY_MMB")
	return events[0].as_text()
