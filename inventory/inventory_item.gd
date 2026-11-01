class_name InventoryItem
extends RefCounted
## Предмет в инвентаре: оружие (WeaponInstance), отдельная деталь оружия (PartInstance, срез 7б, №83) или прочий предмет
## по ItemDefinition (расходник, материал; стопка). Не зависит от автозагрузок: цвет качества берётся из настроек генерации.

var weapon: WeaponInstance
## Граната (№92): тип, качество, модификаторы. Предмет с гранатой экипируется в отдельный слот гранат.
var grenade: GrenadeInstance
## Щит игрока (№93). Предмет со щитом экипируется в отдельный слот щита.
var shield: ShieldInstance
var part: PartInstance
## Настройки генерации: шкала качества и цены детали (у оружия они лежат в самом оружии).
var part_settings: WeaponGenerationSettings
var definition: ItemDefinition
## Число штук в стопке (у оружия всегда 1).
var count: int = 1


static func from_weapon(p_weapon: WeaponInstance) -> InventoryItem:
	var item: InventoryItem = InventoryItem.new()
	item.weapon = p_weapon
	return item


static func from_grenade(p_grenade: GrenadeInstance) -> InventoryItem:
	var item: InventoryItem = InventoryItem.new()
	item.grenade = p_grenade
	return item


static func from_shield(p_shield: ShieldInstance) -> InventoryItem:
	var item: InventoryItem = InventoryItem.new()
	item.shield = p_shield
	return item


static func from_part(p_part: PartInstance, p_settings: WeaponGenerationSettings) -> InventoryItem:
	var item: InventoryItem = InventoryItem.new()
	item.part = p_part
	item.part_settings = p_settings
	return item


static func from_definition(p_definition: ItemDefinition, p_count: int = 1) -> InventoryItem:
	var item: InventoryItem = InventoryItem.new()
	item.definition = p_definition
	item.count = p_count
	return item


func is_weapon() -> bool:
	return weapon != null


func is_part() -> bool:
	return part != null


func is_grenade() -> bool:
	return grenade != null


func is_shield() -> bool:
	return shield != null


func get_category() -> ItemDefinition.Category:
	if shield != null:
		return ItemDefinition.Category.SHIELD
	if grenade != null:
		return ItemDefinition.Category.GRENADE
	if part != null:
		return ItemDefinition.Category.PART
	return ItemDefinition.Category.WEAPON if weapon != null else definition.category


func get_display_name() -> String:
	if shield != null:
		return shield.get_display_name()
	if grenade != null:
		return grenade.get_display_name()
	if part != null:
		return tr(part.part.name_key)
	return weapon.get_display_name() if weapon != null else tr(definition.name_key)


## Уровень оружия, у прочих предметов 0.
func get_level() -> int:
	if shield != null:
		return shield.level
	if grenade != null:
		return grenade.level
	return weapon.level if weapon != null else 0


## Индекс ступени качества оружия, у прочих предметов 0.
func get_quality() -> int:
	if shield != null:
		return shield.quality
	if grenade != null:
		return grenade.quality
	if part != null:
		return part.quality
	return weapon.get_quality() if weapon != null else 0


## Цвет рамки по качеству. У прочих предметов цвет значка.
func get_quality_color() -> Color:
	if shield != null:
		return shield.get_quality_color()
	if grenade != null:
		return grenade.get_quality_color()
	if part != null:
		var part_scale: QualityScale = part_settings.quality_scale if part_settings != null else null
		if part_scale != null and part.quality < part_scale.tiers.size():
			return part_scale.tiers[part.quality].color
		return Color.WHITE
	if weapon != null:
		var scale: QualityScale = weapon.settings.quality_scale if weapon.settings != null else null
		if scale != null and weapon.get_quality() < scale.tiers.size():
			return scale.tiers[weapon.get_quality()].color
		return Color.WHITE
	return definition.icon_color


## Цена одной штуки.
func get_price() -> int:
	if shield != null:
		return shield.get_price()
	if grenade != null:
		return grenade.get_price()
	if part != null:
		return get_part_price()
	return weapon.get_price() if weapon != null else definition.base_price


## Цена детали по справочнику: базовая цена части с множителем её качества и надбавка за модификаторы (как у оружия, без уровня).
func get_part_price() -> int:
	var multiplier: float = 1.0
	if part_settings != null and part_settings.quality_scale != null and part.quality < part_settings.quality_scale.tiers.size():
		multiplier = part_settings.quality_scale.tiers[part.quality].price_multiplier
	var modifier_price: int = part_settings.modifier_price if part_settings != null else 0
	return roundi(float(part.part.base_price) * multiplier + float(part.modifiers.size() * modifier_price))


func get_total_price() -> int:
	return get_price() * count


func is_eternal() -> bool:
	return (weapon != null and weapon.is_eternal) or (grenade != null and grenade.is_eternal) or (shield != null and shield.is_eternal)


## Тип для карточки и сортировки: у оружия тип или семейство, у прочих название категории.
func get_type_text() -> String:
	if shield != null:
		return tr("CARD_SHIELD_TYPE")
	if grenade != null:
		return tr("CARD_GRENADE_TYPE")
	if part != null:
		return tr("PART_TYPE_" + WeaponPart.PartType.keys()[part.part.part_type])
	if weapon != null:
		return weapon.get_type_name()
	return tr("ITEM_CATEGORY_" + ItemDefinition.Category.keys()[definition.category])


## Порядок типа при сортировке: у оружия номер типа, прочие предметы после оружия.
func get_type_order() -> int:
	if shield != null:
		return 160 + shield.definition.kind
	if grenade != null:
		return 150 + grenade.definition.kind
	if part != null:
		return 200 + part.part.part_type
	if weapon != null:
		return weapon.get_weapon_type()
	return 100 + definition.category


func get_maker_text() -> String:
	if part != null:
		return tr(part.part.manufacturer.name_key) if part.part.manufacturer != null else ""
	if weapon != null and weapon.get_manufacturer() != null:
		return tr(weapon.get_manufacturer().name_key)
	return ""


## Можно ли добавить эту стопку к имеющейся.
func can_stack_with(other: InventoryItem) -> bool:
	return definition != null and other.definition == definition and other.count < definition.max_stack