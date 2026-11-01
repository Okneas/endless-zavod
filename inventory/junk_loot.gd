class_name JunkLoot
extends RefCounted
## Хлам (№91): лут только на продажу. Выбирает случайный предмет из списка PropSettings.junk_items по весам выпадения
## (ItemDefinition.drop_weight). Без автозагрузок: настройки и генератор случайных чисел передаются параметрами.


## Случайный хлам стопкой от count_min до count_max штук (не больше размера стопки). null, если список пуст.
static func roll(rng: RandomNumberGenerator, settings: PropSettings, count_min: int = 1, count_max: int = 1) -> InventoryItem:
	if settings == null or settings.junk_items.is_empty():
		return null
	var total: float = 0.0
	for definition: ItemDefinition in settings.junk_items:
		total += maxf(definition.drop_weight, 0.0)
	var pick: float = rng.randf() * total
	var chosen: ItemDefinition = settings.junk_items[settings.junk_items.size() - 1]
	for definition: ItemDefinition in settings.junk_items:
		pick -= maxf(definition.drop_weight, 0.0)
		if pick <= 0.0:
			chosen = definition
			break
	var count: int = clampi(rng.randi_range(count_min, maxi(count_min, count_max)), 1, maxi(chosen.max_stack, 1))
	return InventoryItem.from_definition(chosen, count)
