class_name InventoryActions
extends RefCounted
## Действия над предметами инвентаря (11-UI-design, №55): экипировать, снять, выбросить, использовать.
## Один код для экрана инвентаря и для тестов. Игрок передаётся параметром.


## Можно ли экипировать предмет: оружие не выше уровня персонажа (02-combat-fps, №1).
static func can_equip(item: InventoryItem) -> bool:
	return item.is_weapon() and item.weapon.level <= Progress.level


## Экипировать оружие из инвентаря в слот (-1: первый пустой, иначе активный). Вытесненное оружие
## занимает освободившуюся ячейку, поэтому место всегда есть.
static func equip(player: Player, item: InventoryItem, slot: int = -1) -> bool:
	if not can_equip(item):
		_warn(player, TranslationServer.translate("HUD_NEED_LEVEL").format({"level": item.weapon.level}) if item.is_weapon() else "")
		return false
	var weapon: Weapon = player.get_weapon()
	var target: int = slot if slot >= 0 else weapon.find_equip_slot()
	Inventory.remove(item)
	var replaced: WeaponInstance = weapon.equip_into(target, item.weapon)
	if replaced != null:
		Inventory.add(InventoryItem.from_weapon(replaced))
	return true


## Снять оружие из слота в инвентарь. Последнее оружие снять нельзя, при полном инвентаре тоже.
static func unequip(player: Player, slot: int) -> bool:
	var weapon: Weapon = player.get_weapon()
	if weapon.slots[slot] == null or weapon.occupied_count() <= 1:
		return false
	if Inventory.is_full():
		Inventory.rejected.emit(InventoryItem.from_weapon(weapon.slots[slot]))
		return false
	var removed: WeaponInstance = weapon.remove_from_slot(slot)
	return removed != null and Inventory.add(InventoryItem.from_weapon(removed))


## Выбросить предмет на пол перед игроком (подбор по interact). Вечные предметы выбросить нельзя.
static func drop(player: Player, item: InventoryItem) -> ItemPickup:
	if item.is_eternal() or not Inventory.remove(item):
		return null
	var settings: InventorySettings = Config.data.inventory
	var camera: Camera3D = player.get_viewport().get_camera_3d()
	var forward: Vector3 = -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized() if forward.length() > 0.01 else -player.global_basis.z
	var at: Vector3 = camera.global_position + forward * settings.drop_distance
	var velocity: Vector3 = forward * settings.drop_speed + Vector3.UP * settings.drop_lift
	return ItemPickup.spawn(player.get_parent(), item, at, velocity)


## Использовать расходник: лечит и тратит одну штуку. Не лечит при полном здоровье.
static func use(player: Player, item: InventoryItem) -> bool:
	if item.definition == null or item.definition.heal_amount <= 0.0 or player.health >= player.max_health:
		return false
	player.heal(item.definition.heal_amount)
	item.count -= 1
	if item.count <= 0:
		Inventory.remove(item)
	else:
		Inventory.changed.emit()
	return true


static func _warn(player: Player, text: String) -> void:
	if text != "":
		player.get_tree().call_group(&"hud", &"show_pickup", text, Color(1.0, 0.35, 0.3))
