class_name MenuTheme
extends RefCounted
## Общая тема меню (пауза, настройки, инвентарь): крупный шрифт и плоские кнопки в стиле панелей. Размеры в единицах
## эталона 1920 x 1080 (№78): стандартная тема рассчитана на мелкий интерфейс.


static func build(font_size: int) -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = font_size
	for type_name: String in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type_name, _button_style(Color(0.15, 0.16, 0.2)))
		theme.set_stylebox("hover", type_name, _button_style(Color(0.22, 0.23, 0.29)))
		theme.set_stylebox("pressed", type_name, _button_style(Color(0.1, 0.11, 0.14)))
		theme.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	theme.set_constant("v_separation", "PopupMenu", 12)
	return theme


static func _button_style(background: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(1.0, 1.0, 1.0, 0.18)
	style.set_border_width_all(2)
	style.set_corner_radius_all(5)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 9.0
	style.content_margin_bottom = 9.0
	return style
