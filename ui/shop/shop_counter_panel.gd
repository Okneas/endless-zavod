class_name ShopCounterPanel
extends ModalPanel
## Окно прилавка (срез 8, №88, 05-shop-economy): выставить товар из рюкзака и назначить цену, поменять цену, убрать товар. Цену игрок
## выбирает кнопками «минус/плюс» (шаг в процентах от фактической цены); фактическая цена по формуле показана, а попал ли игрок в цену,
## он узнаёт по реакции покупателей, как в диздоке. Окно временное, строится кодом.

const WIDTH: float = 1300.0

var _index: int = 0
var _selected: InventoryItem
var _price: int = 0


func _ready() -> void:
	super._ready()
	column.custom_minimum_size.x = WIDTH


## Открыть окно прилавка с номером index (с нуля).
func present(index: int) -> void:
	_index = index
	_selected = null
	_build()
	open()


func _build() -> void:
	clear_column()
	var slot: ShopSlot = Shop.counters[_index]
	add_title(tr("HUB_COUNTER_TITLE").format({"number": _index + 1}))
	if not slot.is_empty():
		if slot.holder != null:
			add_line(tr("HUB_COUNTER_BUSY"), Color(1.0, 0.8, 0.5))
		else:
			_price = slot.price
			_editor(slot.item, true)
	elif _selected != null:
		_editor(_selected, false)
	else:
		_item_list()
	add_button(tr("HUB_CLOSE"), close)


# Список предметов рюкзака, которые можно продать.
func _item_list() -> void:
	add_line(tr("HUB_COUNTER_PICK"))
	var list: VBoxContainer = ShopUi.scroll_list(WIDTH, 560.0)
	var any: bool = false
	for item: InventoryItem in Inventory.items:
		if not Shop.can_sell(item):
			continue
		any = true
		list.add_child(ShopUi.item_row(item, ShopUi.describe(item), tr("HUB_ACTUAL_SHORT").format({"price": Shop.actual_price(item)}), tr("HUB_PLACE"), _pick.bind(item)))
	column.add_child(list.get_meta(&"scroll"))
	if not any:
		list.add_child(_dim_label(tr("HUB_BACKPACK_EMPTY")))


func _pick(item: InventoryItem) -> void:
	_selected = item
	_price = Shop.actual_price(item)
	_build()


# Редактор цены: предмет, фактическая цена, кнопки цены и действия.
func _editor(item: InventoryItem, placed: bool) -> void:
	var actual: int = Shop.actual_price(item)
	column.add_child(ShopUi.item_row(item, ShopUi.describe(item), "", "", Callable()))
	add_line(tr("HUB_ACTUAL_PRICE").format({"price": actual}), Color(1.0, 1.0, 1.0, 0.7))
	var step: int = ShopMath.price_step(Config.data.shop, actual)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	for entry: Array in [[-5 * step, "-5"], [-step, "-1"]]:
		row.add_child(_step_button(entry[0], tr("HUB_STEP").format({"sign": entry[1]}), item, placed))
	var price_label: Label = Label.new()
	price_label.text = tr("HUB_PRICE_VALUE").format({"price": _price})
	price_label.add_theme_font_size_override("font_size", 52)
	price_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	price_label.custom_minimum_size.x = 340.0
	price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(price_label)
	for entry: Array in [[step, "+1"], [5 * step, "+5"]]:
		row.add_child(_step_button(entry[0], tr("HUB_STEP").format({"sign": entry[1]}), item, placed))
	column.add_child(row)
	if placed:
		add_button(tr("HUB_TAKE_BACK"), _take_back)
	else:
		add_button(tr("HUB_PLACE_FOR").format({"price": _price}), _place.bind(item))
		add_button(tr("HUB_BACK"), _back)


func _step_button(delta: int, text: String, item: InventoryItem, placed: bool) -> Button:
	var button: Button = Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(150.0, 84.0)
	button.pressed.connect(_change_price.bind(delta, item, placed))
	return button


func _change_price(delta: int, item: InventoryItem, placed: bool) -> void:
	_price = ShopMath.clamp_price(Config.data.shop, Shop.actual_price(item), _price + delta)
	if placed:
		Shop.set_price(_index, _price)
	_build()


func _place(item: InventoryItem) -> void:
	if Shop.place(_index, item, _price):
		_selected = null
	_build()


func _take_back() -> void:
	if not Shop.take_back(_index):
		add_line(tr("HUB_BACKPACK_FULL"), Color(1.0, 0.5, 0.45))
		return
	_selected = null
	_build()


func _back() -> void:
	_selected = null
	_build()


func _dim_label(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.55))
	return label
