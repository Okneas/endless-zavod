class_name InventoryScreen
extends CanvasLayer
## Экран инвентаря по Tab (11-UI-design, раздел 2, набросок автора): слева превью персонажа с оружием, в середине
## пять строк экипировки (четыре слота оружия и слот гранат после прототипа), справа сетка предметов с сортировкой,
## фильтром и счётчиком, три панели одной высоты по центру экрана. Карточка предмета показывается при наведении мыши на
## ячейку или на строку с оружием, как подсказка рядом с курсором (отдельного места в раскладке у неё нет, №76). Действия
## над наведённым предметом идут клавишами InputMap (подсказки на карточке): inventory_equip (ЛКМ), inventory_compare,
## inventory_components, inventory_drop, inventory_unequip. Все размеры заданы в единицах эталона 1920 x 1080: окно другого
## размера растягивает проект само (stretch canvas_items, aspect expand), текст остаётся чётким (№78).
## Открытый инвентарь ставит игру и часы на паузу (флаг pause_in_run, №51), мышь освобождается. Закрывается Tab или Esc.
## Режим оплаты (срез 7, эвакуация лутом): ЛКМ отмечает предметы рюкзака (кроме вечных), внизу сумма и кнопка «Заплатить»,
## кнопка доступна, когда сумма не меньше цены. Закрытие без оплаты ничего не отнимает.

signal opened
signal closed

## Смещение левого верхнего угла карточки от курсора и отступ от краёв экрана.
const CARD_OFFSET: Vector2 = Vector2(30.0, 27.0)
const CARD_MARGIN: float = 7.0
## Шрифт кнопок и списков экрана (стандартная тема рассчитана на мелкий интерфейс).
const CONTROL_FONT_SIZE: int = 26

@onready var _root: Control = $Root
@onready var _preview: Node3D = %CharacterPreview
@onready var _rows_box: VBoxContainer = %EquipmentRows
@onready var _grid: GridContainer = %Grid
@onready var _sort_option: OptionButton = %SortOption
@onready var _direction_button: Button = %DirectionButton
@onready var _filter_option: OptionButton = %FilterOption
@onready var _capacity_label: Label = %CapacityLabel
@onready var _empty_label: Label = %EmptyLabel
@onready var _card: ItemCard = %Card
@onready var _hint: Label = %HintLabel
@onready var _title: Label = %Title
@onready var _equipment_title: Label = %EquipmentTitle
@onready var _preview_title: Label = %PreviewTitle

var _player: Player
var _is_open: bool = false
var _previous_mouse_mode: Input.MouseMode = Input.MOUSE_MODE_CAPTURED
var _cells: Array[ItemCell] = []
var _rows: Array[EquipmentRow] = []
var _sort_key: InventoryView.SortKey = InventoryView.SortKey.NONE
var _ascending: bool = true
var _filter: InventoryView.Filter = InventoryView.Filter.ALL
## Под курсором: ячейка рюкзака (ItemCell), строка экипировки (EquipmentRow) или ничего.
var _hover: Control
## Слот, выбранный кликом по строке экипировки: туда пойдёт «Экипировать». -1: первый пустой или активный.
var _target_slot: int = -1
var _equipped_wrapper: InventoryItem
## Переключатели карточки: остаются включёнными, пока водишь курсором по предметам.
var _compare: bool = false
var _components: bool = false
## Режим оплаты лутом: цена, предметы, отмеченные в оплату, что вызвать после оплаты.
var _payment: bool = false
var _payment_price: int = 0
var _payment_callback: Callable = Callable()
var _marked: Array[InventoryItem] = []
var _payment_box: HBoxContainer
var _payment_label: Label
var _pay_button: Button


func _ready() -> void:
	visible = false
	_root.theme = MenuTheme.build(CONTROL_FONT_SIZE)
	var settings: InventorySettings = Config.data.inventory
	_grid.columns = settings.columns
	for i: int in settings.capacity:
		var cell: ItemCell = ItemCell.new()
		cell.mouse_entered.connect(_set_hover.bind(cell))
		cell.mouse_exited.connect(_clear_hover.bind(cell))
		_grid.add_child(cell)
		_cells.append(cell)
	for i: int in 5:
		var row: EquipmentRow = EquipmentRow.new()
		row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		row.mouse_entered.connect(_set_hover.bind(row))
		row.mouse_exited.connect(_clear_hover.bind(row))
		_rows_box.add_child(row)
		_rows.append(row)
	_fill_options()
	_title.text = tr("INV_TITLE")
	_preview_title.text = tr("INV_CHARACTER")
	_equipment_title.text = tr("INV_EQUIPMENT")
	_empty_label.text = tr("INV_EMPTY_GRID")
	_card.visible = false
	_sort_option.item_selected.connect(_on_sort_selected)
	_filter_option.item_selected.connect(_on_filter_selected)
	_direction_button.pressed.connect(_on_direction_pressed)
	Inventory.changed.connect(_refresh)
	_make_payment_box()
	# Карточка поверх всего, в том числе подсказки внизу и панели оплаты (её добавляем выше, до подъёма).
	_card.get_parent().move_child(_card, -1)


## Связывает экран с игроком (вызывает HUD).
func bind_player(player: Player) -> void:
	_player = player
	_player.get_weapon().loadout_changed.connect(_refresh)
	_player.get_weapon().slot_changed.connect(func(_slot: int) -> void: _refresh())


func is_open() -> bool:
	return _is_open


func is_payment_mode() -> bool:
	return _payment


## Открыть экран в режиме оплаты лутом: отметить предметы на сумму не меньше price и заплатить. on_paid(сумма) вызывается
## после оплаты, предметы к этому моменту уже убраны из рюкзака.
func open_payment(price: int, on_paid: Callable) -> void:
	if _player == null:
		return
	_payment = true
	_payment_price = price
	_payment_callback = on_paid
	_marked.clear()
	if _is_open:
		_refresh()
	else:
		open()


## Сумма цен отмеченных предметов.
func marked_total() -> int:
	var total: int = 0
	for item: InventoryItem in _marked:
		total += item.get_total_price()
	return total


func _make_payment_box() -> void:
	_payment_box = HBoxContainer.new()
	_payment_box.name = "PaymentBox"
	_payment_box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_payment_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_payment_box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_payment_box.offset_top = -170.0
	_payment_box.offset_bottom = -110.0
	_payment_box.add_theme_constant_override("separation", 30)
	_payment_label = Label.new()
	_payment_label.add_theme_font_size_override("font_size", 34)
	_payment_box.add_child(_payment_label)
	_pay_button = Button.new()
	_pay_button.text = tr("INV_PAY")
	_pay_button.pressed.connect(_on_pay_pressed)
	_payment_box.add_child(_pay_button)
	_payment_box.visible = false
	_root.add_child(_payment_box)


func _on_pay_pressed() -> void:
	if not _payment or marked_total() < _payment_price:
		return
	var total: int = marked_total()
	for item: InventoryItem in _marked:
		Inventory.remove(item)
	var callback: Callable = _payment_callback
	_payment = false
	_marked.clear()
	close()
	if callback.is_valid():
		callback.call(total)


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"inventory_toggle"):
		if _is_open:
			close()
		elif _player != null and not _player.is_dead:
			open()
	if not _is_open:
		return
	if _card.visible:
		_move_card()
	# Действия опрашиваются здесь, а не в _input: так они одинаково работают от клавиши и от Input.action_press.
	if Input.is_action_just_pressed(&"inventory_equip"):
		_on_equip_pressed()
	if Input.is_action_just_pressed(&"inventory_compare"):
		_compare = not _compare
		_refresh()
	if Input.is_action_just_pressed(&"inventory_components"):
		_components = not _components
		_refresh()
	if Input.is_action_just_pressed(&"inventory_drop"):
		_on_drop_pressed()
	if Input.is_action_just_pressed(&"inventory_unequip"):
		_on_unequip_pressed()


func _unhandled_input(event: InputEvent) -> void:
	if _is_open and event.is_action_pressed(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if _is_open or _player == null:
		return
	_is_open = true
	_previous_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if Config.data.pause_in_run:
		get_tree().paused = true
	UserSettings.enter_menu()
	_reset_state()
	get_tree().call_group(&"debug_overlay", "set_visible", false)
	_hint.text = "%s   ·   %s" % [tr("INV_HINT_CLOSE").format({"key": KeyHint.text(&"inventory_toggle")}), tr("INV_HINT_HOVER")]
	visible = true
	_refresh()
	opened.emit()


func close() -> void:
	if not _is_open:
		return
	_is_open = false
	_payment = false
	_marked.clear()
	_payment_box.visible = false
	visible = false
	_reset_state()
	UserSettings.leave_menu()
	get_tree().call_group(&"debug_overlay", "set_visible", true)
	if get_tree().paused:
		get_tree().paused = false
	# Мышь возвращается в прежний режим: если игрок сам освободил её по Esc, она остаётся свободной.
	Input.mouse_mode = _previous_mouse_mode
	closed.emit()


func _reset_state() -> void:
	_set_hovered_flag(_hover, false)
	_hover = null
	_target_slot = -1
	_equipped_wrapper = null
	_compare = false
	_components = false
	_card.visible = false


# --- обновление

func _refresh() -> void:
	if not _is_open or _player == null:
		return
	var level: int = Progress.level
	var weapon: Weapon = _player.get_weapon()
	var view: Array[InventoryItem] = InventoryView.build(Inventory.items, _sort_key, _ascending, _filter)
	for i: int in _cells.size():
		_cells[i].set_item(view[i] if i < view.size() else null, level)
	for i: int in _cells.size():
		_cells[i].marked = _payment and _cells[i].item != null and _marked.has(_cells[i].item)
	_payment_box.visible = _payment
	if _payment:
		_payment_label.text = tr("INV_PAYMENT_STATUS").format({"selected": marked_total(), "price": _payment_price})
		_pay_button.disabled = marked_total() < _payment_price
	_capacity_label.text = tr("INV_CAPACITY").format({"used": Inventory.items.size(), "max": Inventory.get_capacity()})
	_empty_label.visible = Inventory.items.is_empty()
	# Над оружием из рюкзака подсвечен слот, в который оно пойдёт.
	var hovered_cell: ItemCell = _hover as ItemCell
	var target: int = _effective_target()
	var shows_target: bool = hovered_cell != null and hovered_cell.item != null and hovered_cell.item.is_weapon()
	for i: int in 4:
		var row: EquipmentRow = _rows[i]
		row.setup(i, weapon.slots[i], level, tr("INV_EMPTY_SLOT"))
		row.active = i == weapon.active_slot
		row.selected = i == _target_slot or (shows_target and i == target)
	_rows[4].setup(4, null, level, tr("INV_GRENADE_SLOT"), true)
	_preview.show_weapon(weapon.instance)
	_show_card()


func _effective_target() -> int:
	if _target_slot >= 0:
		return _target_slot
	return _player.get_weapon().find_equip_slot()


# Карточка того, на что наведён курсор: предмет рюкзака или оружие в слоте. Пустое место карточку убирает.
func _show_card() -> void:
	var weapon: Weapon = _player.get_weapon()
	var item: InventoryItem = null
	var context: Dictionary = {"player_level": Progress.level, "components": _components}
	var cell: ItemCell = _hover as ItemCell
	var row: EquipmentRow = _hover as EquipmentRow
	if cell != null and cell.item != null:
		item = cell.item
		# Сравнение с оружием в слоте-цели, а если слот пуст, то с тем, что сейчас в руках.
		var target_weapon: WeaponInstance = weapon.slots[_effective_target()]
		context["compare"] = _compare
		context["reference"] = target_weapon if target_weapon != null else weapon.instance
		context["equipped"] = false
		context["can_equip"] = InventoryActions.can_equip(item)
		context["can_drop"] = not item.is_eternal()
		context["can_use"] = item.definition != null and item.definition.heal_amount > 0.0 and _player.health < _player.max_health
	elif row != null and not row.locked and weapon.slots[row.slot] != null:
		if _equipped_wrapper == null or _equipped_wrapper.weapon != weapon.slots[row.slot]:
			_equipped_wrapper = InventoryItem.from_weapon(weapon.slots[row.slot])
		item = _equipped_wrapper
		context["equipped"] = true
		context["can_unequip"] = weapon.occupied_count() > 1 and not Inventory.is_full()
	if item == null:
		_card.visible = false
		return
	_card.max_height = _root.size.y - 14.0
	_card.show_item(item, context)
	_card.reset_size()
	_fit_card.call_deferred()


# После раскладки: если карточка выше экрана, она уплотняется по ступеням, затем встаёт к курсору.
func _fit_card() -> void:
	if not _card.visible or not _is_open or _hover == null:
		return
	_card.reset_size()
	if _card.shrink_if_needed():
		_card.reset_size()
		_fit_card.call_deferred()
		return
	_move_card()


# Карточка как подсказка у курсора: справа и ниже него, у правого края слева от него, у нижнего сдвигается вверх.
# Курсор карточка не закрывает, мышь через неё проходит.
func _move_card() -> void:
	if _hover == null:
		return
	var viewport_size: Vector2 = _root.size
	# По минимальному размеру: размер карточки обновляется только после раскладки.
	var card_size: Vector2 = _card.get_combined_minimum_size()
	var pointer: Vector2 = _pointer()
	var x: float = pointer.x + CARD_OFFSET.x
	if x + card_size.x > viewport_size.x - CARD_MARGIN:
		x = pointer.x - CARD_OFFSET.x - card_size.x
	var y: float = clampf(pointer.y + CARD_OFFSET.y, CARD_MARGIN, maxf(CARD_MARGIN, viewport_size.y - card_size.y - CARD_MARGIN))
	_card.global_position = Vector2(maxf(x, CARD_MARGIN), y)


# Точка, к которой привязана карточка: мышь над наведённым элементом, иначе центр элемента (в тестах без мыши).
func _pointer() -> Vector2:
	var rect: Rect2 = _hover.get_global_rect()
	var mouse: Vector2 = _hover.get_global_mouse_position()
	return mouse if rect.has_point(mouse) else rect.get_center()


# --- наведение

func _set_hover(control: Control) -> void:
	if _hover == control:
		return
	_set_hovered_flag(_hover, false)
	_hover = control
	_set_hovered_flag(control, true)
	_refresh()


func _clear_hover(control: Control) -> void:
	if _hover == control:
		_set_hover(null)


func _set_hovered_flag(control: Control, value: bool) -> void:
	if not is_instance_valid(control):
		return
	if control is ItemCell:
		(control as ItemCell).hovered = value
	elif control is EquipmentRow:
		(control as EquipmentRow).hovered = value


# --- действия над наведённым предметом

# ЛКМ: оружие из рюкзака в слот-цель, аптечку использовать, по строке экипировки выбрать слот-цель (повтор снимает выбор).
func _on_equip_pressed() -> void:
	var cell: ItemCell = _hover as ItemCell
	var row: EquipmentRow = _hover as EquipmentRow
	if _payment:
		if cell != null and cell.item != null and not cell.item.is_eternal():
			if _marked.has(cell.item):
				_marked.erase(cell.item)
			else:
				_marked.append(cell.item)
		_refresh()
		return
	if cell != null and cell.item != null:
		var item: InventoryItem = cell.item
		if item.is_weapon():
			if InventoryActions.equip(_player, item, _effective_target()):
				_target_slot = -1
		elif InventoryActions.use(_player, item):
			get_tree().call_group(&"hud", &"show_pickup", tr("HUD_ITEM_USED").format({"name": item.get_display_name()}), Color.WHITE)
	elif row != null and not row.locked:
		_target_slot = -1 if _target_slot == row.slot else row.slot
	_refresh()


func _on_drop_pressed() -> void:
	if _payment:
		return
	var cell: ItemCell = _hover as ItemCell
	if cell != null and cell.item != null and not cell.item.is_eternal():
		InventoryActions.drop(_player, cell.item)
	_refresh()


func _on_unequip_pressed() -> void:
	if _payment:
		return
	var row: EquipmentRow = _hover as EquipmentRow
	if row != null and not row.locked and row.weapon != null:
		InventoryActions.unequip(_player, row.slot)
	_refresh()


func _on_sort_selected(index: int) -> void:
	_sort_key = _sort_option.get_item_id(index) as InventoryView.SortKey
	_refresh()


func _on_filter_selected(index: int) -> void:
	_filter = _filter_option.get_item_id(index) as InventoryView.Filter
	_refresh()


func _on_direction_pressed() -> void:
	_ascending = not _ascending
	_direction_button.text = tr("INV_ASCENDING") if _ascending else tr("INV_DESCENDING")
	_refresh()


func _fill_options() -> void:
	_sort_option.clear()
	for entry: Array in [[InventoryView.SortKey.NONE, "INV_SORT_NONE"], [InventoryView.SortKey.LEVEL, "INV_SORT_LEVEL"], [InventoryView.SortKey.QUALITY, "INV_SORT_QUALITY"], [InventoryView.SortKey.TYPE, "INV_SORT_TYPE"], [InventoryView.SortKey.MAKER, "INV_SORT_MAKER"], [InventoryView.SortKey.PRICE, "INV_SORT_PRICE"]]:
		_sort_option.add_item(tr(entry[1]), entry[0])
	_filter_option.clear()
	_filter_option.add_item(tr("INV_FILTER_ALL"), InventoryView.Filter.ALL)
	_filter_option.add_item(tr("ITEM_CATEGORY_WEAPON"), InventoryView.Filter.WEAPON)
	_filter_option.add_item(tr("ITEM_CATEGORY_CONSUMABLE"), InventoryView.Filter.CONSUMABLE)
	_filter_option.add_item(tr("ITEM_CATEGORY_MATERIAL"), InventoryView.Filter.MATERIAL)
	_filter_option.add_item(tr("ITEM_CATEGORY_PART"), InventoryView.Filter.PART)
	_direction_button.text = tr("INV_ASCENDING")
