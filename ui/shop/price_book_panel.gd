class_name PriceBookPanel
extends ModalPanel
## Справочник цен (срез 8, №88, 05-shop-economy): базовые цены всех частей оружия, множители качества и надбавки. По ним игрок сам
## считает фактическую цену и оптимальную цену на прилавке: цена оружия = множитель уровня x сумма (цена части x множитель качества) +
## надбавка за модификаторы. Окно временное, строится кодом.

const WIDTH: float = 1500.0


func _ready() -> void:
	super._ready()
	column.custom_minimum_size.x = WIDTH


func present() -> void:
	clear_column()
	add_title(tr("HUB_PRICE_BOOK"))
	var weapons: WeaponGenerationSettings = Config.data.weapons
	add_line(tr("BOOK_FORMULA"), Color(1.0, 1.0, 1.0, 0.75))
	var tiers: PackedStringArray = []
	for tier: QualityTier in weapons.quality_scale.tiers:
		tiers.append("%s x%.2f" % [tr(tier.name_key), tier.price_multiplier])
	add_line(tr("BOOK_QUALITY").format({"tiers": ", ".join(tiers)}), Color(1.0, 0.9, 0.55))
	add_line(tr("BOOK_EXTRAS").format({"level": roundi(weapons.price_per_level * 100.0), "modifier": weapons.modifier_price}), Color(1.0, 0.9, 0.55))
	var list: VBoxContainer = ShopUi.scroll_list(WIDTH, 620.0)
	column.add_child(list.get_meta(&"scroll"))
	var parts: Array[WeaponPart] = []
	for part: WeaponPart in WeaponCatalog.for_directory(weapons.parts_directory).parts:
		parts.append(part)
	parts.sort_custom(func(a: WeaponPart, b: WeaponPart) -> bool:
		if a.part_type != b.part_type:
			return a.part_type < b.part_type
		var maker_a: String = tr(a.manufacturer.name_key) if a.manufacturer != null else ""
		var maker_b: String = tr(b.manufacturer.name_key) if b.manufacturer != null else ""
		if maker_a != maker_b:
			return maker_a < maker_b
		return tr(a.name_key) < tr(b.name_key))
	var last_type: int = -1
	for part: WeaponPart in parts:
		if part.part_type != last_type:
			last_type = part.part_type
			var header: Label = Label.new()
			header.text = tr("PART_TYPE_" + WeaponPart.PartType.keys()[part.part_type])
			header.add_theme_color_override("font_color", Color(0.6, 0.85, 1.0))
			list.add_child(header)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 20)
		var name_label: Label = Label.new()
		name_label.text = tr(part.name_key)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		var maker: Label = Label.new()
		maker.text = tr(part.manufacturer.name_key) if part.manufacturer != null else "-"
		maker.custom_minimum_size.x = 380.0
		maker.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.65))
		row.add_child(maker)
		var price: Label = Label.new()
		price.text = str(part.base_price)
		price.custom_minimum_size.x = 120.0
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		price.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		row.add_child(price)
		list.add_child(row)
	add_button(tr("HUB_CLOSE"), close)
	open()
