extends Node
## Инвентарь игрока (05-shop-economy, №39): рюкзак на заданное число ячеек. Экипированное оружие лежит в слотах
## узла Weapon и в лимит не входит. Стопка расходников занимает одну ячейку. Живёт между комнатами и перезапусками
## сцены, как Progress. Какие предметы теряются при смерти, решит срез 7.

signal changed
## Предмет не поместился: инвентарь полон.
signal rejected(item: InventoryItem)

var items: Array[InventoryItem] = []


func _ready() -> void:
	Progress.level_changed.connect(_on_level_changed)


func get_capacity() -> int:
	return Config.data.inventory.capacity


func is_full() -> bool:
	return items.size() >= get_capacity()


## Положить предмет. Расходники сначала доливаются в неполные стопки, остаток занимает новую ячейку.
## Возвращает false, если ячеек не хватило (остаток остаётся в item.count, сигнал rejected).
func add(item: InventoryItem) -> bool:
	if item.definition != null:
		for existing: InventoryItem in items:
			if existing.definition == item.definition and existing.count < item.definition.max_stack:
				var moved: int = mini(item.count, item.definition.max_stack - existing.count)
				existing.count += moved
				item.count -= moved
				if item.count <= 0:
					changed.emit()
					return true
	if is_full():
		rejected.emit(item)
		changed.emit()
		return false
	items.append(item)
	changed.emit()
	return true


func remove(item: InventoryItem) -> bool:
	var index: int = items.find(item)
	if index < 0:
		return false
	items.remove_at(index)
	changed.emit()
	return true


func clear() -> void:
	items.clear()
	changed.emit()


# Вечное оружие (стартовый пистолет) растёт вместе с персонажем и в инвентаре тоже.
func _on_level_changed(level: int) -> void:
	for item: InventoryItem in items:
		if item.weapon != null and item.weapon.follows_player_level:
			item.weapon.level = level
	changed.emit()
