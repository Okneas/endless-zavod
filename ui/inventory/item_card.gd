class_name ItemCard
extends PanelContainer
## Всплывающая карточка предмета, показывается при наведении (11-UI-design, раздел 3, эталон Borderlands).
## Оружие: цветная по качеству шапка с картинкой, DPS, ряд из пяти плиток основных характеристик с иконками,
## вторичные характеристики, плашка стихии, особенности с иконками, цена. Режим «Сравнить» добавляет стрелки лучше/хуже,
## режим «Компоненты» показывает вместо характеристик список частей. Прочие предметы: название, описание, количество, цена.
## Действия показаны подсказками клавиш внизу (клавиши из InputMap), нажимает их экран инвентаря. Содержимое
## собирается кодом в узле Content. Все размеры заданы в единицах эталона 1920 x 1080 (№78): окно другого размера
## растягивает их само (stretch проекта), поэтому текст остаётся чётким.

const WIDTH: float = 560.0
## Поля панели карточки со всех сторон.
const PANEL_MARGIN: float = 20.0
## Ширина содержимого: карточка минус поля стиля панели.
const INNER_WIDTH: float = WIDTH - PANEL_MARGIN * 2.0
## Ширина названия в шапке (содержимое минус поля шапки) и правой колонки шапки (уровень и картинка).
const HEADER_WIDTH: float = INNER_WIDTH - 32.0
const HEADER_SIDE_WIDTH: float = 166.0
const COLOR_DIM: Color = Color(0.72, 0.72, 0.78)
const COLOR_RED: Color = Color(1.0, 0.4, 0.35)
const COLOR_GOLD: Color = Color(1.0, 0.85, 0.3)
const TILE_BACKGROUND: Color = Color(0.1, 0.11, 0.15)
# Ключ значения, ключ названия в таблице переводов, что лучше (1 больше, -1 меньше), значок плитки, короткая подпись плитки.
const PRIMARY: Array = [
	["damage", "CARD_STAT_DAMAGE", 1, StatIcon.Kind.DAMAGE, "CARD_STAT_DAMAGE"],
	["spread", "CARD_STAT_SPREAD", -1, StatIcon.Kind.SPREAD, "CARD_STAT_SPREAD"],
	["rate", "CARD_STAT_RATE", 1, StatIcon.Kind.RATE, "CARD_STAT_RATE"],
	["reload", "CARD_STAT_RELOAD", -1, StatIcon.Kind.RELOAD, "CARD_STAT_RELOAD_SHORT"],
	["magazine", "CARD_STAT_MAGAZINE", 1, StatIcon.Kind.MAGAZINE, "CARD_STAT_MAGAZINE"],
]
const SECONDARY: Array = [
	["range", "CARD_STAT_RANGE", 1], ["recoil", "CARD_STAT_RECOIL", -1], ["aim", "CARD_STAT_AIM", -1],
	["crit", "CARD_STAT_CRIT", 1], ["stability", "CARD_STAT_STABILITY", 1],
]

## Предельная высота карточки (экран минус поля). Не помещается: карточка уплотняется по ступеням (shrink_if_needed).
var max_height: float = 0.0

@onready var _content: VBoxContainer = %Content

## Ступень уплотнения: 0 обычная, 1 без описаний особенностей (компоненты: плотнее и мельче), 2 узкая шапка без картинки.
var _level: int = 0
var _item: InventoryItem
var _context: Dictionary = {}


func _ready() -> void:
	custom_minimum_size.x = WIDTH
	# Карточка только показывает, мышь через неё проходит к ячейкам.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _flat(Color(0.09, 0.09, 0.12, 0.97), Color(1.0, 1.0, 1.0, 0.3), 6, 3, PANEL_MARGIN))


## Показать предмет. context: components (режим компонентов), compare (режим сравнения), reference (WeaponInstance
## для сравнения), player_level, equipped (оружие в слоте), can_equip, can_unequip, can_drop, can_use.
func show_item(item: InventoryItem, context: Dictionary) -> void:
	_item = item
	_context = context
	_populate(item, context, 0)
	visible = true


## Высота текста с переносом известна только после раскладки, поэтому вызывать отложенно после show_item и reset_size.
## Если карточка выше max_height, пересобирает её на ступень плотнее и возвращает true (размер нужно обновить, вызвать ещё раз).
func shrink_if_needed() -> bool:
	var last_level: int = 1 if _context.get("components", false) else 2
	if max_height <= 0.0 or _item == null or _level >= last_level or get_combined_minimum_size().y <= max_height:
		return false
	_populate(_item, _context, _level + 1)
	return true


func _populate(item: InventoryItem, context: Dictionary, level: int) -> void:
	_level = level
	for child: Node in _content.get_children():
		_content.remove_child(child)
		child.queue_free()
	# Режим компонентов с первой ступени тесный: узкая шапка, плотные промежутки, без подписи режима.
	var tight: bool = level >= 1 and item.is_weapon() and context.get("components", false)
	_content.add_theme_constant_override("separation", 3 if tight else 10)
	_add(_header(item, context, tight or level >= 2))
	if item.is_weapon():
		if context.get("components", false):
			_build_components(item, tight)
		else:
			_build_weapon(item, context)
	elif item.is_part():
		_build_part(item)
	else:
		_build_misc(item)
	_build_footer(item, context)


# --- оружие, основной вид

func _build_weapon(item: InventoryItem, context: Dictionary) -> void:
	var weapon: WeaponInstance = item.weapon
	var stats: WeaponStats = weapon.compute_stats()
	var compare: bool = context.get("compare", false)
	var reference: WeaponInstance = context.get("reference") if compare else null
	var ref_stats: WeaponStats = reference.compute_stats() if reference != null and reference != weapon else null
	if compare:
		var note: String = tr("CARD_COMPARE_WITH").format({"name": reference.get_display_name()}) if ref_stats != null else tr("CARD_COMPARE_NOTHING")
		_add(_label(note, 20, COLOR_GOLD, INNER_WIDTH))
	_add(_dps_bar(weapon, reference if ref_stats != null else null))
	var tiles: HBoxContainer = HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 7)
	for entry: Array in PRIMARY:
		tiles.add_child(_primary_tile(entry, stats, ref_stats))
	_add(tiles)
	var secondary: GridContainer = GridContainer.new()
	secondary.columns = 2
	secondary.add_theme_constant_override("h_separation", 27)
	secondary.add_theme_constant_override("v_separation", 3)
	for entry: Array in SECONDARY:
		secondary.add_child(_secondary_cell(entry, stats, ref_stats))
	_add(secondary)
	var element_plate: Control = _element_plate(stats)
	if element_plate != null:
		_add(element_plate)
	for feature: PartFeature in weapon.get_features():
		_add(_feature_row(feature))


func _dps_bar(weapon: WeaponInstance, reference: WeaponInstance) -> Control:
	var bar: PanelContainer = PanelContainer.new()
	bar.add_theme_stylebox_override("panel", _flat(Color(0.07, 0.08, 0.11), Color(1.0, 1.0, 1.0, 0.14), 5, 2, 10.0))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(_label(str(roundi(weapon.get_dps())), 44, Color.WHITE))
	var caption: Label = _label(tr("CARD_DPS"), 22, COLOR_DIM)
	caption.size_flags_vertical = Control.SIZE_SHRINK_END
	row.add_child(caption)
	if reference != null:
		row.add_child(_arrow(_direction(weapon.get_dps(), reference.get_dps(), 1)))
	bar.add_child(row)
	return bar


func _primary_tile(entry: Array, stats: WeaponStats, ref_stats: WeaponStats) -> Control:
	var tile: PanelContainer = PanelContainer.new()
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.add_theme_stylebox_override("panel", _flat(TILE_BACKGROUND, Color(1.0, 1.0, 1.0, 0.14), 5, 2, 7.0))
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	tile.add_child(box)
	var top: HBoxContainer = HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_CENTER
	top.add_theme_constant_override("separation", 5)
	var icon: StatIcon = StatIcon.new()
	icon.kind = entry[3] as StatIcon.Kind
	top.add_child(icon)
	var direction: int = 0
	if ref_stats != null:
		direction = _direction(_stat_value(stats, entry[0]), _stat_value(ref_stats, entry[0]), entry[2])
	top.add_child(_arrow(direction))
	box.add_child(top)
	var value: Label = _label(_stat_text(stats, entry[0]), 25, Color.WHITE)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(value)
	var caption: String = tr(entry[4])
	if entry[0] == "damage" and stats.pellets > 1:
		caption += " ×%d" % stats.pellets
	var name_label: Label = _label(caption, 17, COLOR_DIM)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)
	return tile


func _secondary_cell(entry: Array, stats: WeaponStats, ref_stats: WeaponStats) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 7)
	var name_label: Label = _label(tr(entry[1]), 20, COLOR_DIM)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(_label(_stat_text(stats, entry[0]), 20, Color.WHITE))
	var direction: int = 0
	if ref_stats != null:
		direction = _direction(_stat_value(stats, entry[0]), _stat_value(ref_stats, entry[0]), entry[2])
	row.add_child(_arrow(direction))
	return row


# Плашка стихии: значок и строка «тип, урон в секунду, шанс» (эталон: отдельная цветная полоса).
func _element_plate(stats: WeaponStats) -> Control:
	if stats.element == CombatEnums.Element.NONE:
		return null
	var color: Color = _element_color(stats.element)
	var plate: PanelContainer = PanelContainer.new()
	plate.add_theme_stylebox_override("panel", _flat(Color(color.r * 0.22, color.g * 0.22, color.b * 0.22), color, 5, 2, 10.0))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 13)
	var icon: ElementIcon = ElementIcon.new()
	icon.custom_minimum_size = Vector2(43.0, 43.0)
	icon.set_element(stats.element)
	row.add_child(icon)
	row.add_child(_label(_element_text(stats), 22, color, INNER_WIDTH - 100.0))
	plate.add_child(row)
	return plate


func _feature_row(feature: PartFeature) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 13)
	var icon: FeatureIcon = FeatureIcon.new()
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(icon)
	icon.set_feature(feature)
	var text: VBoxContainer = VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	text.add_child(_label(tr(feature.name_key), 24, Color.WHITE))
	if _level < 1:
		text.add_child(_label(tr(feature.description_key).format({"value": roundi(feature.value * 100.0)}), 18, COLOR_DIM, INNER_WIDTH - 66.0))
	row.add_child(text)
	return row


# --- оружие, режим «Компоненты»

func _build_components(item: InventoryItem, tight: bool) -> void:
	var weapon: WeaponInstance = item.weapon
	if not tight:
		_add(_label(tr("CARD_BTN_COMPONENTS"), 22, COLOR_DIM))
	var body: PartInstance = weapon.get_body()
	for instance: PartInstance in weapon.parts:
		var part: WeaponPart = instance.part
		var block: VBoxContainer = VBoxContainer.new()
		block.add_theme_constant_override("separation", 0)
		var title: HBoxContainer = HBoxContainer.new()
		var line: String = "%s: %s" % [tr("PART_TYPE_" + WeaponPart.PartType.keys()[part.part_type]), tr(part.name_key)]
		var title_label: Label = _label(line, 22 if tight else 24, Color.WHITE)
		title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_child(title_label)
		if part.base_price > 0:
			title.add_child(_label(tr("CARD_PART_PRICE").format({"price": part.base_price}), 20, COLOR_GOLD))
		block.add_child(title)
		var maker: String = tr(part.manufacturer.name_key) if part.manufacturer != null else "-"
		var detail: String = "%s · %s" % [maker, _quality_name(weapon, instance.quality)]
		if instance == body:
			detail += " · " + tr("CARD_PART_BRAND")
			detail += " · " + tr("CARD_SIGHT_OPTIC" if weapon.get_sight() == CombatEnums.SightType.OPTIC else "CARD_SIGHT_IRON")
		block.add_child(_label(detail, 17 if tight else 18, _quality_color(weapon, instance.quality), INNER_WIDTH))
		var pieces: PackedStringArray = []
		var shifts: Dictionary = PartInfo.plus_minus(part)
		if shifts["plus"] != "":
			pieces.append(tr("CARD_PLUS").format({"stat": tr(shifts["plus"]).to_lower()}))
		if shifts["minus"] != "":
			pieces.append(tr("CARD_MINUS").format({"stat": tr(shifts["minus"]).to_lower()}))
		var names: PackedStringArray = []
		for rolled: RolledModifier in instance.modifiers:
			names.append(tr(rolled.modifier.name_key))
		for feature: PartFeature in instance.features:
			names.append(tr(feature.name_key))
		if part.signature != null:
			names.append(tr(part.signature.name_key))
		if names.size() > 0:
			pieces.append(tr("CARD_MODIFIERS").format({"names": ", ".join(names)}))
		if pieces.size() > 0:
			block.add_child(_label(" · ".join(pieces), 17 if tight else 18, COLOR_DIM, INNER_WIDTH))
		_add(block)


# --- деталь оружия

func _build_part(item: InventoryItem) -> void:
	var instance: PartInstance = item.part
	var part: WeaponPart = instance.part
	var maker: String = tr(part.manufacturer.name_key) if part.manufacturer != null else "-"
	_add(_label("%s · %s" % [maker, _part_quality_name(item)], 22, item.get_quality_color(), INNER_WIDTH))
	var shifts: Dictionary = PartInfo.plus_minus(part)
	if shifts["plus"] != "":
		_add(_label(tr("CARD_PLUS").format({"stat": tr(shifts["plus"]).to_lower()}), 22, Color(0.45, 1.0, 0.5), INNER_WIDTH))
	if shifts["minus"] != "":
		_add(_label(tr("CARD_MINUS").format({"stat": tr(shifts["minus"]).to_lower()}), 22, COLOR_RED, INNER_WIDTH))
	var names: PackedStringArray = []
	for rolled: RolledModifier in instance.modifiers:
		names.append(tr(rolled.modifier.name_key))
	if names.size() > 0:
		_add(_label(tr("CARD_MODIFIERS").format({"names": ", ".join(names)}), 20, COLOR_DIM, INNER_WIDTH))
	if part.signature != null:
		_add(_feature_row(part.signature))
	for feature: PartFeature in instance.features:
		_add(_feature_row(feature))
	var fits: PackedStringArray = []
	for weapon_type: CombatEnums.WeaponType in part.weapon_types:
		fits.append(tr("WEAPON_TYPE_" + CombatEnums.WeaponType.keys()[weapon_type]))
	_add(_label(tr("CARD_PART_FITS").format({"types": ", ".join(fits)}) if fits.size() > 0 else tr("CARD_PART_FITS_ANY"), 18, COLOR_DIM, INNER_WIDTH))


func _part_quality_name(item: InventoryItem) -> String:
	var quality_scale: QualityScale = item.part_settings.quality_scale if item.part_settings != null else null
	if quality_scale != null and item.part.quality < quality_scale.tiers.size():
		return tr(quality_scale.tiers[item.part.quality].name_key)
	return ""


# --- прочие предметы

func _build_misc(item: InventoryItem) -> void:
	var definition: ItemDefinition = item.definition
	_add(_label(tr(definition.description_key), 22, Color.WHITE, INNER_WIDTH))
	if item.count > 1 or definition.max_stack > 1:
		_add(_label(tr("CARD_COUNT").format({"count": item.count}), 22, COLOR_DIM))


# --- шапка и низ

# Шапка залита цветом качества (эталон): название на всю ширину, под ним тип, метки качества и производитель слева,
# уровень и картинка справа. Узкая шапка (тесные ступени) без картинки: всё в строке сведений.
func _header(item: InventoryItem, context: Dictionary, slim: bool) -> Control:
	var color: Color = item.get_quality_color()
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _flat(Color(color.r * 0.3, color.g * 0.3, color.b * 0.3), color, 5, 3, 13.0))
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	panel.add_child(column)
	column.add_child(_label(item.get_display_name(), 30, Color.WHITE, HEADER_WIDTH))
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 13)
	column.add_child(row)
	var left: VBoxContainer = VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 3)
	row.add_child(left)
	var info: HFlowContainer = HFlowContainer.new()
	info.add_theme_constant_override("h_separation", 13)
	info.add_theme_constant_override("v_separation", 3)
	info.add_child(_label(item.get_type_text(), 20, COLOR_DIM, 0.0 if slim else HEADER_SIDE_WIDTH * 1.5))
	left.add_child(info)
	var right: VBoxContainer = VBoxContainer.new()
	right.custom_minimum_size.x = HEADER_SIDE_WIDTH
	right.add_theme_constant_override("separation", 3)
	if item.is_weapon():
		var weapon: WeaponInstance = item.weapon
		info.add_child(_label(_quality_name(weapon, weapon.get_quality()), 20, color))
		var marks: QualityMarks = QualityMarks.new()
		marks.set_marks(weapon.get_quality() + 1, color)
		marks.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		info.add_child(marks)
		if weapon.is_eternal:
			info.add_child(_label(tr("CARD_ETERNAL"), 20, COLOR_GOLD))
		var too_high: bool = weapon.level > int(context.get("player_level", 1))
		var level_text: String = tr("CARD_REQUIRED_LEVEL").format({"level": weapon.level}) if too_high else tr("CARD_LEVEL").format({"level": weapon.level})
		var level_label: Label = _label(level_text, 22, COLOR_RED if too_high else Color.WHITE, 0.0 if slim else HEADER_SIDE_WIDTH)
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var maker: Manufacturer = weapon.get_manufacturer()
		if slim:
			info.add_child(level_label)
			if maker != null:
				info.add_child(_label(tr(maker.name_key), 20, COLOR_DIM))
		else:
			right.add_child(level_label)
			if maker != null:
				var maker_row: HBoxContainer = HBoxContainer.new()
				maker_row.add_theme_constant_override("separation", 10)
				var badge: ColorRect = ColorRect.new()
				badge.color = maker.color
				badge.custom_minimum_size = Vector2(20.0, 20.0)
				var holder: CenterContainer = CenterContainer.new()
				holder.add_child(badge)
				maker_row.add_child(holder)
				maker_row.add_child(_label(tr(maker.name_key), 20, COLOR_DIM))
				left.add_child(maker_row)
	if not slim:
		var picture: ItemPicture = ItemPicture.new()
		picture.set_item(item)
		picture.custom_minimum_size = Vector2(HEADER_SIDE_WIDTH, 73.0)
		right.add_child(picture)
		row.add_child(right)
	return panel


# Цена и подсказки клавиш внизу (в эталоне Borderlands вместо кнопок).
func _build_footer(item: InventoryItem, context: Dictionary) -> void:
	if item.get_price() > 0:
		var price_text: String = tr("CARD_PRICE_STACK").format({"price": item.get_price(), "total": item.get_total_price()}) if item.count > 1 else tr("CARD_PRICE").format({"price": item.get_price()})
		var price: Label = _label(price_text, 24, COLOR_GOLD)
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		_add(price)
	var hints: HFlowContainer = HFlowContainer.new()
	hints.add_theme_constant_override("h_separation", 20)
	hints.add_theme_constant_override("v_separation", 7)
	for entry: Array in _hint_entries(item, context):
		hints.add_child(_hint(entry[0], entry[1], entry[2]))
	_add(hints)


# Какие действия есть у наведённого предмета: действие InputMap, ключ подписи, доступно ли сейчас.
func _hint_entries(item: InventoryItem, context: Dictionary) -> Array:
	var entries: Array = []
	var compare: bool = context.get("compare", false)
	var components: bool = context.get("components", false)
	if item.is_weapon():
		if context.get("equipped", false):
			entries.append([&"inventory_equip", "CARD_BTN_SELECT_SLOT", true])
			entries.append([&"inventory_unequip", "CARD_BTN_UNEQUIP", context.get("can_unequip", false)])
		else:
			entries.append([&"inventory_equip", "CARD_BTN_EQUIP", context.get("can_equip", false)])
			entries.append([&"inventory_compare", "CARD_BTN_EXIT_COMPARE" if compare else "CARD_BTN_COMPARE", true])
		entries.append([&"inventory_components", "CARD_BTN_BACK" if components else "CARD_BTN_COMPONENTS", true])
		if not context.get("equipped", false):
			entries.append([&"inventory_drop", "CARD_BTN_DROP", context.get("can_drop", false)])
	elif item.is_part():
		entries.append([&"inventory_drop", "CARD_BTN_DROP", context.get("can_drop", false)])
	else:
		if item.definition.heal_amount > 0.0:
			entries.append([&"inventory_equip", "CARD_BTN_USE", context.get("can_use", false)])
		entries.append([&"inventory_drop", "CARD_BTN_DROP", context.get("can_drop", false)])
	return entries


func _hint(action: StringName, text_key: String, enabled: bool) -> Control:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var cap: PanelContainer = PanelContainer.new()
	cap.add_theme_stylebox_override("panel", _flat(Color(0.16, 0.17, 0.22), Color(1.0, 1.0, 1.0, 0.45 if enabled else 0.2), 5, 2, 7.0))
	cap.add_child(_label(KeyHint.text(action), 18, Color.WHITE if enabled else COLOR_DIM))
	row.add_child(cap)
	row.add_child(_label(tr(text_key), 20, Color.WHITE if enabled else Color(1.0, 1.0, 1.0, 0.35)))
	return row


# --- характеристики

func _stat_value(stats: WeaponStats, key: String) -> float:
	match key:
		"damage":
			return stats.damage
		"spread":
			return stats.spread_deg
		"rate":
			return stats.fire_rate
		"reload":
			return stats.reload_time
		"magazine":
			return float(stats.magazine_size)
		"range":
			return stats.weapon_range
		"recoil":
			return stats.recoil_deg
		"aim":
			return stats.aim_time
		"crit":
			return stats.crit_chance
		"stability":
			return (1.0 - stats.movement_spread_mult) * 100.0
	return 0.0


func _stat_text(stats: WeaponStats, key: String) -> String:
	var value: float = _stat_value(stats, key)
	match key:
		"damage":
			return "%.0f" % value
		"spread":
			return "%.1f°" % value
		"rate":
			return tr("CARD_UNIT_PER_SECOND").format({"value": "%.1f" % value})
		"reload":
			return tr("CARD_UNIT_SECONDS").format({"value": "%.1f" % value})
		"magazine":
			return "%d" % roundi(value)
		"range":
			return "%.0f" % value
		"recoil":
			return "%.1f°" % value
		"aim":
			return "%.2f" % value
		"crit":
			return "%d%%" % roundi(value * 100.0)
		"stability":
			return "%d%%" % roundi(value)
	return ""


# 1: новое лучше сравниваемого, -1: хуже, 0: одинаково. better: что лучше, больше (1) или меньше (-1).
func _direction(value: float, reference: float, better: int) -> int:
	var tolerance: float = maxf(absf(reference), 1.0) * 0.001
	if absf(value - reference) <= tolerance:
		return 0
	return better if value > reference else -better


func _arrow(direction: int) -> StatArrow:
	var arrow: StatArrow = StatArrow.new()
	arrow.direction = direction
	return arrow


# --- стихия

func _element_text(stats: WeaponStats) -> String:
	var elements: ElementSettings = Config.data.elements
	var name: String = tr("ELEMENT_" + CombatEnums.Element.keys()[stats.element])
	# Стихия накладывается каждым попаданием: шанс 100%.
	match stats.element:
		CombatEnums.Element.ELECTRIC:
			return tr("CARD_ELEMENT_ELECTRIC").format({"name": name, "dps": roundi(stats.damage * elements.electric_dps_fraction), "chance": 100})
		CombatEnums.Element.ACID:
			return tr("CARD_ELEMENT_ACID").format({"name": name, "value": roundi((elements.acid_damage_taken_multiplier - 1.0) * 100.0), "chance": 100})
		CombatEnums.Element.FROST:
			return tr("CARD_ELEMENT_FROST").format({"name": name, "value": roundi((1.0 - elements.frost_speed_multiplier) * 100.0), "chance": 100})
	return tr("CARD_ELEMENT_FIRE").format({"name": name})


func _element_color(element: CombatEnums.Element) -> Color:
	return WeaponModelBuilder.ELEMENT_COLORS.get(element, Color.WHITE)


# --- мелочи

func _quality_name(weapon: WeaponInstance, quality: int) -> String:
	var scale: QualityScale = weapon.settings.quality_scale if weapon.settings != null else null
	if scale == null or quality >= scale.tiers.size():
		return str(quality)
	return tr(scale.tiers[quality].name_key)


func _quality_color(weapon: WeaponInstance, quality: int) -> Color:
	var scale: QualityScale = weapon.settings.quality_scale if weapon.settings != null else null
	if scale == null or quality >= scale.tiers.size():
		return Color.WHITE
	return scale.tiers[quality].color


func _flat(background: Color, border: Color, radius: int, border_width: int, margin: float) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(margin)
	return style


# min_width больше нуля включает перенос по словам и задаёт ширину, при которой считается высота.
func _label(text: String, font_size: int, color: Color, min_width: float = 0.0) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if min_width > 0.0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = min_width
	return label


func _add(node: Control) -> void:
	_content.add_child(node)
