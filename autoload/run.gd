extends Node
## Состояние забега (срез 7, №82): номер зоны, исход, итоги. Деньги, опыт и уровень мира лежат в Progress и живут между
## забегами. Смерть отнимает весь лут без пометки «Вечный» (04-extraction): рюкзак и оружие в слотах, остаётся стартовый
## пистолет. Деньги и опыт сохраняются. Построение зон делает сцена забега (run/run.gd), здесь только данные и правила.

signal run_started
## Игрок вошёл в зону (в том числе первую и после отладочного переключения).
signal zone_entered(zone: int)
## Забег закончился: смертью, эвакуацией или победой над боссом отдела.
signal run_ended(outcome: int)

enum Outcome { NONE, DEATH, EVACUATED, BOSS_DEFEATED }
## Что делает портал, когда игрок в него вошёл.
enum Exit { NEXT_ZONE, EVACUATE, BOSS_VICTORY }

var active: bool = false
var zone: int = 1
var outcome: Outcome = Outcome.NONE
## Снаряжение, которое игрок несёт между хабом и забегом (снимок Weapon.export_loadout()); пусто, пока игра только началась.
var carried_loadout: Array = []
var run_seed: int = 0
## Для экрана итогов: деньги к началу забега, сколько предметов потеряно при смерти, уровень мира до и после.
var money_at_start: int = 0
var lost_items: int = 0
var world_level_before: int = 0
var world_level_after: int = 0


## Начало забега: первая зона. Сид нужен для случайностей забега (зона эвакуации, способ оплаты); 0: выбрать самому.
func start(seed_value: int = 0) -> void:
	active = true
	zone = 1
	outcome = Outcome.NONE
	run_seed = seed_value if seed_value != 0 else randi()
	money_at_start = Progress.money
	lost_items = 0
	world_level_before = Progress.world_level
	world_level_after = Progress.world_level
	run_started.emit()
	zone_entered.emit(zone)


## Уровень зоны по формуле: min(уровень мира, база отдела + номер зоны) (03-run-structure).
func zone_level() -> int:
	return ZoneMath.zone_level(Config.data.zones, Progress.world_level, zone)


## Перейти в следующую зону. Возвращает false в последней зоне отдела (там только босс и выход).
func advance_zone() -> bool:
	if not active or zone >= Config.data.zones.zones_in_department:
		return false
	zone += 1
	zone_entered.emit(zone)
	return true


## Отладочный переход на любую зону отдела (клавиши ] и [).
func set_zone(number: int) -> void:
	zone = clampi(number, 1, Config.data.zones.zones_in_department)
	zone_entered.emit(zone)


## Игрок вошёл в открытый портал: дальше зона, эвакуация или победа над боссом.
func use_exit(kind: Exit) -> void:
	match kind:
		Exit.NEXT_ZONE:
			advance_zone()
		Exit.EVACUATE:
			finish(Outcome.EVACUATED)
		Exit.BOSS_VICTORY:
			finish(Outcome.BOSS_DEFEATED)


## Конец забега. Смерть отнимает лут (нужен игрок: у него оружие в слотах), победа над боссом поднимает уровень мира.
func finish(p_outcome: Outcome, player: Player = null) -> void:
	if not active:
		return
	active = false
	outcome = p_outcome
	if p_outcome == Outcome.DEATH and player != null:
		lost_items = lose_loot(player)
	if p_outcome == Outcome.BOSS_DEFEATED:
		Progress.raise_world_level()
	world_level_after = Progress.world_level
	run_ended.emit(p_outcome)


## Смерть: теряется всё, что не вечное, в рюкзаке и в слотах оружия. Вечное оружие (стартовый пистолет) остаётся в
## руках, даже если игрок положил его в рюкзак. Возвращает число потерянных предметов.
func lose_loot(player: Player) -> int:
	var lost: int = 0
	var weapon: Weapon = player.get_weapon()
	var equipped_eternal: bool = false
	for instance: WeaponInstance in weapon.slots:
		if instance != null and instance.is_eternal:
			equipped_eternal = true
	if not equipped_eternal:
		for item: InventoryItem in Inventory.items.duplicate():
			if item.is_eternal():
				Inventory.remove(item)
				var replaced: WeaponInstance = weapon.equip_into(weapon.find_equip_slot(), item.weapon)
				if replaced != null and not replaced.is_eternal:
					lost += 1
				break
	for item: InventoryItem in Inventory.items.duplicate():
		if not item.is_eternal():
			Inventory.remove(item)
			lost += item.count
	for slot: int in weapon.slots.size():
		var instance: WeaponInstance = weapon.slots[slot]
		if instance != null and not instance.is_eternal and weapon.remove_from_slot(slot) != null:
			lost += 1
	# Граната в слоте (№92): невечная теряется, вечная остаётся в слоте или возвращается из рюкзака, без неё выдаётся стартовая.
	var equipped_grenade: GrenadeInstance = Inventory.grenade
	if equipped_grenade != null and not equipped_grenade.is_eternal:
		Inventory.grenade = null
		lost += 1
	if Inventory.grenade == null:
		var kept: InventoryItem = null
		for item: InventoryItem in Inventory.items:
			if item.grenade != null and item.grenade.is_eternal:
				kept = item
		if kept != null:
			Inventory.remove(kept)
			Inventory.grenade = kept.grenade
		else:
			Inventory.reset_grenade()
	# Щит в слоте (№93): так же, как граната.
	var equipped_shield: ShieldInstance = Inventory.shield
	if equipped_shield != null and not equipped_shield.is_eternal:
		Inventory.shield = null
		lost += 1
	if Inventory.shield == null:
		var kept_shield: InventoryItem = null
		for item: InventoryItem in Inventory.items:
			if item.shield != null and item.shield.is_eternal:
				kept_shield = item
		if kept_shield != null:
			Inventory.remove(kept_shield)
			Inventory.shield = kept_shield.shield
		else:
			Inventory.reset_shield()
	return lost
