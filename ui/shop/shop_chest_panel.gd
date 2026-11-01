class_name ShopChestPanel
extends ModalPanel
## Окно сундука (срез 8, №88): слева рюкзак (20 ячеек), справа сундук (по ShopSettings.chest_capacity). Нажатием предмет переезжает в другую
## сторону. Окно временное, строится кодом.

const WIDTH: float = 1500.0
const LIST_HEIGHT: float = 640.0


func _ready() -> void:
	super._ready()
	column.custom_minimum_size.x = WIDTH


func present() -> void:
	_build()
	open()


func _build() -> void:
	clear_column()
	add_title(tr("HUB_CHEST"))
	var columns: HBoxContainer = HBoxContainer.new()
	columns.add_theme_constant_override("separation", 30)
	column.add_child(columns)
	columns.add_child(_side(tr("HUB_BACKPACK_COUNT").format({"count": Inventory.items.size(), "max": Inventory.get_capacity()}), Inventory.items, tr("HUB_TO_CHEST"), _to_chest))
	columns.add_child(_side(tr("HUB_CHEST_COUNT").format({"count": Shop.chest.size(), "max": Shop.chest_capacity()}), Shop.chest, tr("HUB_TO_BACKPACK"), _to_backpack))
	if Shop.chest_is_full():
		add_line(tr("HUB_CHEST_FULL"), Color(1.0, 0.7, 0.45))
	add_button(tr("HUB_CLOSE"), close)


func _side(title: String, items: Array, button_text: String, action: Callable) -> Control:
	var box: VBoxContainer = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header: Label = Label.new()
	header.text = title
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(header)
	var list: VBoxContainer = ShopUi.scroll_list(WIDTH * 0.48, LIST_HEIGHT)
	box.add_child(list.get_meta(&"scroll"))
	for item: InventoryItem in items.duplicate():
		list.add_child(ShopUi.item_row(item, ShopUi.describe(item), "", button_text, action.bind(item)))
	return box


func _to_chest(item: InventoryItem) -> void:
	Shop.store(item)
	_build()


func _to_backpack(item: InventoryItem) -> void:
	Shop.retrieve(item)
	_build()
