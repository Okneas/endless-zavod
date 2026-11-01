extends Node
## Инвентарь игрока (05-shop-economy, №39): рюкзак на заданное число ячеек. Экипированное оружие лежит в слотах
## узла Weapon и в лимит не входит. Стопка расходников занимает одну ячейку. Живёт между комнатами и перезапусками
## сцены, как Progress. Какие предметы теряются при смерти, решит срез 7.

signal changed
## Предмет не поместился: инвентарь полон.
signal rejected(item: InventoryItem)

var items: Array[InventoryItem] = []
## Граната в слоте гранат (№92). Живёт между сценами; стартовая вечная выдаётся при первом обращении.
var grenade: GrenadeInstance:
	get:
		if grenade == null and _starter_allowed:
			grenade = _make_generator().starter(Progress.level)
		return grenade
	set(value):
		grenade = value
		_starter_allowed = value != null
		grenade_changed.emit()

signal grenade_changed

## Щит в слоте щита (№93). Живёт между сценами; стартовый вечный выдаётся при первом обращении.
var shield: ShieldInstance:
	get:
		if shield == null and _shield_starter_allowed:
			shield = _make_shield_generator().starter(Progress.level)
		return shield
	set(value):
		shield = value
		_shield_starter_allowed = value != null
		shield_changed.emit()

signal shield_changed

var _starter_allowed: bool = true
var _shield_starter_allowed: bool = true


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


## Вернуть стартовую вечную гранату в слот (начало игры, смерть без неё).
func reset_grenade() -> void:
	_starter_allowed = true
	grenade = null
	grenade = _make_generator().starter(Progress.level)


## Вернуть стартовый вечный щит в слот (начало игры, смерть без него).
func reset_shield() -> void:
	_shield_starter_allowed = true
	shield = null
	shield = _make_shield_generator().starter(Progress.level)


func _make_shield_generator() -> ShieldGenerator:
	return ShieldGenerator.new(Config.data.shields, Config.data.weapons.quality_scale)


func _make_generator() -> GrenadeGenerator:
	return GrenadeGenerator.new(Config.data.grenades, Config.data.weapons.quality_scale)


# Вечное оружие (стартовый пистолет) растёт вместе с персонажем и в инвентаре тоже.
func _on_level_changed(level: int) -> void:
	for item: InventoryItem in items:
		if item.weapon != null and item.weapon.follows_player_level:
			item.weapon.level = level
		if item.grenade != null and item.grenade.is_eternal:
			item.grenade.level = level
		if item.shield != null and item.shield.is_eternal:
			item.shield.level = level
	if grenade != null and grenade.is_eternal:
		grenade.level = level
	if shield != null and shield.is_eternal:
		shield.level = level
	changed.emit()
