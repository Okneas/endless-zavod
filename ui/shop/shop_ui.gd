class_name ShopUi
extends RefCounted
## Общие кусочки окон магазина (срез 8, №88): значок предмета и строка предмета со ценой и кнопкой. Окна временные, строятся кодом.


## Значок предмета в рамке цвета качества (рисуется тем же ItemIcon, что и ячейки инвентаря).
class ItemSwatch extends Control:
	var item: InventoryItem

	func _init(p_item: InventoryItem = null) -> void:
		item = p_item
		custom_minimum_size = Vector2(88.0, 64.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var frame: Rect2 = Rect2(Vector2.ZERO, size)
		draw_rect(frame, Color(0.06, 0.07, 0.1))
		if item != null:
			ItemIcon.draw(self, frame.grow(-6.0), item)
			draw_rect(frame.grow(-1.0), item.get_quality_color(), false, 3.0)


## Строка предмета: значок, название с подписью, цена, кнопка. action вызывается нажатием кнопки (пустой Callable: без кнопки).
static func item_row(item: InventoryItem, subtitle: String, price_text: String, button_text: String, action: Callable, enabled: bool = true) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.custom_minimum_size.y = 76.0
	row.add_child(ItemSwatch.new(item))
	var texts: VBoxContainer = VBoxContainer.new()
	texts.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	texts.add_theme_constant_override("separation", 0)
	var name_label: Label = Label.new()
	name_label.text = item.get_display_name()
	name_label.clip_text = true
	texts.add_child(name_label)
	var sub: Label = Label.new()
	sub.text = subtitle
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.6))
	texts.add_child(sub)
	row.add_child(texts)
	if price_text != "":
		var price: Label = Label.new()
		price.text = price_text
		price.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		row.add_child(price)
	if action.is_valid():
		var button: Button = Button.new()
		button.text = button_text
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(260.0, 64.0)
		button.disabled = not enabled
		button.pressed.connect(action)
		row.add_child(button)
	return row


## Прокручиваемый список строк фиксированной высоты внутри колонки панели.
static func scroll_list(width: float, height: float) -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(width, height)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)
	list.set_meta(&"scroll", scroll)
	return list


## Подпись предмета в строках: тип и уровень (у оружия), тип детали и производитель (у деталей).
static func describe(item: InventoryItem) -> String:
	if item.weapon != null:
		return "%s · %s" % [item.get_type_text(), tr_level(item)]
	if item.part != null:
		return "%s · %s" % [item.get_type_text(), item.get_maker_text()]
	return item.get_type_text()


static func tr_level(item: InventoryItem) -> String:
	return TranslationServer.translate("CARD_LEVEL").format({"level": item.get_level()})
