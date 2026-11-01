class_name InventoryView
extends RefCounted
## Вид сетки инвентаря: сортировка и фильтр по категории (№55). Сами предметы не переставляются,
## экран показывает отсортированную копию. Не зависит от автозагрузок.

enum SortKey { NONE, LEVEL, QUALITY, TYPE, MAKER, PRICE }
## Фильтр: все предметы или одна категория (значения после ALL совпадают с ItemDefinition.Category).
enum Filter { ALL, WEAPON, CONSUMABLE, MATERIAL, PART, JUNK, GRENADE, SHIELD }


## Отфильтрованная и отсортированная копия. Равные по ключу предметы остаются в исходном порядке.
static func build(items: Array[InventoryItem], sort_key: SortKey, ascending: bool, filter: Filter) -> Array[InventoryItem]:
	var indexed: Array = []
	for i: int in items.size():
		var item: InventoryItem = items[i]
		if filter == Filter.ALL or int(item.get_category()) == int(filter) - 1:
			indexed.append([item, i])
	if sort_key != SortKey.NONE:
		indexed.sort_custom(func(a: Array, b: Array) -> bool:
			var left: Variant = _key(a[0], sort_key)
			var right: Variant = _key(b[0], sort_key)
			if left == right:
				return a[1] < b[1]
			return left < right if ascending else left > right)
	var result: Array[InventoryItem] = []
	for entry: Array in indexed:
		result.append(entry[0])
	return result


static func _key(item: InventoryItem, sort_key: SortKey) -> Variant:
	match sort_key:
		SortKey.LEVEL:
			return item.get_level()
		SortKey.QUALITY:
			return item.get_quality()
		SortKey.TYPE:
			return item.get_type_order()
		SortKey.MAKER:
			return item.get_maker_text()
		SortKey.PRICE:
			return item.get_price()
	return 0