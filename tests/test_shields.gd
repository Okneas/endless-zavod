@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Щиты (№93). Щит игрока: данные и генерация, впитывание урона и остаток в здоровье, восстановление после паузы, виды с
## особенностями (нова, шип, поглотитель), слот и экипировка, потеря при смерти, полоса в HUD. Щиты врагов: впитывание и остаток, ток
## бьёт сильнее, стихии цепляются после пробития, восстановление по данным, рост с уровнем зоны, префикс «Щитоносный».
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_shields.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.

const PLAYER_POS: Vector3 = Vector3(0.0, 0.05, 15.0)
const ENEMY_POS: Vector3 = Vector3(0.0, 0.05, 0.0)

var _fails: int = 0
var _room: Node
var _player
var _hud
var _inventory
var _config
var _actions
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _ev: Dictionary = {"hurt": 0, "shield_hit": 0}


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _secs(seconds: float) -> void:
	await _frames(ceili(seconds * 120.0))


# Щит заданного вида без модификаторов, первого уровня, в слоте и полный.
func _equip(key: String, definition: ShieldDefinition = null):
	var generator: ShieldGenerator = ShieldGenerator.new(_config.data.shields, _config.data.weapons.quality_scale)
	var instance: ShieldInstance = generator.generate(_rng, 1, definition if definition != null else load("res://data/content/shields/%s.tres" % key))
	instance.modifiers.clear()
	_inventory.shield = instance
	_player.get_shield().refresh(true)
	return instance


func _reset_player() -> void:
	_player.is_dead = false
	_player.global_position = PLAYER_POS
	_player.velocity = Vector3.ZERO
	_player.set_health(_player.max_health)
	_player.get_shield().refresh(true)


func _clear() -> void:
	for node: Node in get_nodes_in_group(&"enemies"):
		node.free()
	for child: Node in _room.get_children():
		var kind: String = child.get_script().get_global_name() if child.get_script() != null else ""
		if kind == "BlastEffect" or kind == "DamageNumber":
			child.free()
	await _frames(2)


# Враг из сцены со своей копией настроек: стоит на месте и не атакует, щит и прочее задаётся tweak.
func _enemy(scene_name: String, pos: Vector3 = ENEMY_POS, tweak: Dictionary = {}, health_scale: float = 1.0, modifier: EnemyModifier = null):
	var enemy = (load("res://enemies/%s.tscn" % scene_name) as PackedScene).instantiate()
	enemy.settings = enemy.settings.duplicate()
	enemy.settings.aggro_range = 0.5
	enemy.settings.shield_capacity = 0.0
	for key: String in tweak:
		enemy.settings.set(key, tweak[key])
	enemy.health_scale = health_scale
	if modifier != null:
		enemy.apply_modifier(modifier)
	_room.add_child(enemy)
	enemy.global_position = pos
	return enemy


func _hit(enemy, amount: float, element: int = CombatEnums.Element.NONE) -> bool:
	var info: DamageInfo = DamageInfo.create(amount, false, enemy.global_position + Vector3(0.0, 1.0, 0.0))
	info.apply_vulnerability = false
	info.element = element
	return enemy.take_hit(info)


func _initialize() -> void:
	create_timer(300.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	_config = root.get_node("Config")
	_inventory = root.get_node("Inventory")
	_actions = load("res://inventory/inventory_actions.gd")
	_rng.seed = 93
	root.get_node("Progress").reset()
	_inventory.clear()
	_room = (load("res://rooms/test_room.tscn") as PackedScene).instantiate()
	_room.get_node("Enemies").free()
	_room.get_node("Dummies").queue_free()
	root.add_child(_room)
	await _frames(10)
	_player = _room.get_node("Player")
	_hud = _room.get_node("Hud")
	_player.damaged.connect(func(_amount: float, _from: Vector3) -> void: _ev["hurt"] += 1)
	_player.shield_damaged.connect(func(_amount: float, _from: Vector3) -> void: _ev["shield_hit"] += 1)
	await _run()
	print("=== FAILS: ", _fails)
	quit(_fails)


func _run() -> void:
	var shields: ShieldSettings = _config.data.shields

	print("--- Данные и генерация")
	var kinds: Dictionary = {}
	var texts_ok: bool = true
	for definition: ShieldDefinition in shields.types:
		kinds[definition.kind] = true
		texts_ok = texts_ok and tr(definition.name_key) != definition.name_key and tr(definition.name_lower_key) != definition.name_lower_key and tr(definition.description_key) != definition.description_key
	for modifier: ShieldModifier in shields.modifiers:
		texts_ok = texts_ok and tr(modifier.name_key) != modifier.name_key
	_check(shields.types.size() >= 6 and kinds.size() == 4 and shields.modifiers.size() >= 4 and shields.starter != null and texts_ok, "6 типов щитов, все четыре вида особенности, модификаторы и стартовый щит, названия в переводах")
	var generator: ShieldGenerator = ShieldGenerator.new(shields, _config.data.weapons.quality_scale)
	var generated_ok: bool = true
	for i: int in 300:
		var made: ShieldInstance = generator.generate(_rng, 1 + i % 5)
		var stats: ShieldInstance.Stats = made.compute_stats()
		var effect_on_plain: bool = false
		for rolled: ShieldInstance.Rolled in made.modifiers:
			effect_on_plain = effect_on_plain or (rolled.modifier.stat == ShieldModifier.Stat.EFFECT and made.definition.kind == ShieldDefinition.Kind.STANDARD)
		generated_ok = generated_ok and stats.capacity > 0.0 and made.get_price() > 0 and made.get_display_name() != "" \
				and made.modifiers.size() <= _config.data.weapons.quality_scale.tiers[made.quality].modifier_count and not effect_on_plain
	_check(generated_ok, "300 случайных щитов: ёмкость и цена больше нуля, число модификаторов не больше, чем даёт качество, усиления особенности нет у обычных щитов")
	var level_one: ShieldInstance = generator.generate(_rng, 1, shields.starter)
	var level_five: ShieldInstance = generator.generate(_rng, 5, shields.starter)
	level_one.modifiers.clear()
	level_five.modifiers.clear()
	_check(level_five.compute_stats().capacity > level_one.compute_stats().capacity, "ёмкость растёт с уровнем щита (%.0f -> %.0f)" % [level_one.compute_stats().capacity, level_five.compute_stats().capacity])

	print("--- Стартовый щит и слот")
	_inventory.reset_shield()
	var starter: ShieldInstance = _inventory.shield
	_player.get_shield().refresh(true)
	_check(starter != null and starter.is_eternal and starter.level == root.get_node("Progress").level and is_equal_approx(_player.get_shield().maximum, starter.compute_stats().capacity), "стартовый щит вечный, уровня персонажа, игрок полностью им защищён")
	_check(_hud._shield_row.visible and is_equal_approx(_hud._shield_bar.max_value, _player.get_shield().maximum), "в HUD видна полоса щита над здоровьем")

	print("--- Щит игрока: впитывание и остаток")
	var plain: ShieldInstance = _equip("standard")
	var stats_plain: ShieldInstance.Stats = plain.compute_stats()
	var cap: float = stats_plain.capacity
	_reset_player()
	_ev["hurt"] = 0
	_ev["shield_hit"] = 0
	_player.take_damage(20.0)
	_check(_player.health == _player.max_health and is_equal_approx(_player.get_shield().current, cap - 20.0) and _ev["hurt"] == 0 and _ev["shield_hit"] == 1, "удар 20 впитан щитом: здоровье цело, щит %.0f из %.0f, вспышка щита, не здоровья" % [_player.get_shield().current, cap])
	_check(is_equal_approx(_hud._shield_bar.value, cap - 20.0), "полоса щита в HUD показывает остаток")
	_player.take_damage(cap)
	_check(is_equal_approx(_player.get_shield().current, 0.0) and _player.health == _player.max_health - 20 and _ev["hurt"] == 1, "удар сильнее остатка щита: щит 0, лишние 20 ушли в здоровье")
	await _secs(stats_plain.recharge_delay * 0.5)
	_check(is_equal_approx(_player.get_shield().current, 0.0), "до конца задержки (%.1f с) щит не восстанавливается" % stats_plain.recharge_delay)
	await _secs(stats_plain.recharge_delay * 0.5 + 1.0)
	var recharged: float = _player.get_shield().current
	_check(recharged > 0.0 and recharged < cap, "после задержки щит восстанавливается (%.0f из %.0f за секунду)" % [recharged, cap])
	await _secs(cap / maxf(stats_plain.recharge_rate, 0.1) + 1.0)
	_check(is_equal_approx(_player.get_shield().current, cap), "щит восстанавливается до края")
	_player.take_damage(5.0)
	await _secs(stats_plain.recharge_delay * 0.5)
	_player.take_damage(5.0)
	await _secs(stats_plain.recharge_delay * 0.6)
	_check(is_equal_approx(_player.get_shield().current, cap - 10.0), "новый удар сбрасывает задержку восстановления")
	_inventory.shield = null
	_check(not _player.get_shield().has_shield() and not _hud._shield_row.visible, "без щита в слоте полоса скрыта")
	_player.set_health(_player.max_health)
	_player.take_damage(10.0)
	_check(_player.health == _player.max_health - 10, "без щита весь урон идёт в здоровье")

	print("--- Виды щитов")
	await _clear()
	var nova: ShieldInstance = _equip("nova")
	var target = _enemy("chaser", ENEMY_POS + Vector3(0.0, 0.0, 12.0), {}, 40.0)
	_reset_player()
	await _frames(3)
	_player.take_damage(1.0)
	_check(is_equal_approx(target.health, target.get_max_health()), "нова молчит, пока щит цел")
	_player.take_damage(nova.compute_stats().capacity)
	_check(target.health < target.get_max_health() and not target.is_dead, "нова: когда щит упал до нуля, враг рядом ранен (%.0f из %.0f)" % [target.health, target.get_max_health()])
	await _clear()
	var far = _enemy("chaser", ENEMY_POS, {}, 40.0)
	_reset_player()
	_equip("nova")
	await _frames(3)
	_player.take_damage(9999.0)
	_check(is_equal_approx(far.health, far.get_max_health()), "нова не достаёт до врага за пределами радиуса")
	await _clear()
	var spiker = _enemy("chaser", PLAYER_POS + Vector3(0.0, 0.0, -2.0), {}, 40.0)
	_reset_player()
	_equip("spike")
	await _frames(3)
	_player.take_damage(5.0)
	var after_first: float = spiker.health
	_player.take_damage(5.0)
	_check(after_first < spiker.get_max_health() and is_equal_approx(spiker.health, after_first), "шип: поглощённое попадание ранит врага вплотную, пауза между срабатываниями держится")
	await _clear()
	var absorber: ShieldDefinition = (load("res://data/content/shields/absorb.tres") as ShieldDefinition).duplicate()
	absorber.base_capacity = 1000.0
	absorber.effect_chance = shields.absorb_chance_cap
	absorber.effect_restore = 1.0
	_equip("absorb", absorber)
	_reset_player()
	for i: int in 300:
		_player.take_damage(1.0)
	_check(_player.get_shield().current > 900.0 and _player.health == _player.max_health, "поглотитель: часть попаданий сведена на нет и вернула щит (%.0f из 1000 после 300 ударов)" % _player.get_shield().current)

	print("--- Слот, экипировка, смерть")
	_inventory.clear()
	_inventory.reset_shield()
	var eternal: ShieldInstance = _inventory.shield
	var found: ShieldInstance = generator.generate(_rng, 1, load("res://data/content/shields/heavy.tres"))
	var found_item: InventoryItem = InventoryItem.from_shield(found)
	_inventory.add(found_item)
	_check(found_item.get_category() == ItemDefinition.Category.SHIELD and found_item.get_price() > 0 and found_item.get_type_text() != "CARD_SHIELD_TYPE", "предмет-щит: категория, цена, подпись типа")
	_check(_actions.equip(_player, found_item, -1) and _inventory.shield == found and _inventory.items.size() == 1 and _inventory.items[0].shield == eternal, "экипировка: новый щит в слоте, прежний вечный вернулся в рюкзак")
	_check(is_equal_approx(_player.get_shield().maximum, found.compute_stats().capacity), "игрок сразу получил ёмкость нового щита")
	_check(_inventory.items[0].is_eternal() and _actions.drop(_player, _inventory.items[0]) == null and not root.get_node("Shop").can_sell(_inventory.items[0]), "вечный щит нельзя выбросить и продать")
	var high: ShieldInstance = generator.generate(_rng, root.get_node("Progress").level + 5)
	var high_item: InventoryItem = InventoryItem.from_shield(high)
	_inventory.add(high_item)
	_check(not _actions.can_equip(high_item) and not _actions.equip_shield(_player, high_item) and _inventory.shield == found, "щит выше уровня персонажа экипировать нельзя")
	_check(_actions.unequip_shield() and _inventory.shield == null and _inventory.items.size() == 3, "снять щит в рюкзак можно")
	for item: InventoryItem in _inventory.items:
		if item.shield == found:
			_actions.equip_shield(_player, item)
			break
	var lost: int = root.get_node("Run").lose_loot(_player)
	_check(_inventory.shield != null and _inventory.shield.is_eternal and lost >= 1, "смерть: невечный щит потерян, вечный вернулся в слот")

	print("--- Щиты врагов")
	await _clear()
	var guard = _enemy("gunner", ENEMY_POS, {"shield_capacity": 100.0})
	_check(is_equal_approx(guard.max_shield, 100.0) and is_equal_approx(guard.shield, 100.0), "щит врага берётся из настроек типа (%.0f)" % guard.max_shield)
	var health_before: float = guard.health
	_hit(guard, 40.0)
	_check(is_equal_approx(guard.shield, 60.0) and is_equal_approx(guard.health, health_before), "удар 40: щит 60, здоровье цело")
	_hit(guard, 80.0)
	_check(is_equal_approx(guard.shield, 0.0) and is_equal_approx(guard.health, health_before - 20.0), "удар 80 при щите 60: щит 0, 20 ушло в здоровье")
	await _clear()
	var electric_target = _enemy("gunner", ENEMY_POS, {"shield_capacity": 100.0})
	_hit(electric_target, 20.0, CombatEnums.Element.ELECTRIC)
	var multiplier: float = _config.data.elements.electric_shield_multiplier
	_check(multiplier > 1.0 and is_equal_approx(electric_target.shield, 100.0 - 20.0 * multiplier), "ток съедает щит в %.2f раза быстрее" % multiplier)
	_check(not electric_target.is_electrified(), "пока щит цел, ток на врага не накладывается")
	await _clear()
	var acid_target = _enemy("gunner", ENEMY_POS, {"shield_capacity": 30.0})
	_hit(acid_target, 10.0, CombatEnums.Element.ACID)
	var covered: bool = not acid_target.is_acidified()
	_hit(acid_target, 60.0, CombatEnums.Element.ACID)
	_check(covered and acid_target.is_acidified(), "кислота цепляется только после пробития щита")
	await _clear()
	var still = _enemy("gunner", ENEMY_POS, {"shield_capacity": 100.0})
	_hit(still, 50.0)
	await _secs(3.0)
	_check(is_equal_approx(still.shield, 50.0), "по умолчанию щит врага не восстанавливается")
	var healing = _enemy("gunner", ENEMY_POS + Vector3(5.0, 0.0, 0.0), {"shield_capacity": 100.0, "shield_recharge_delay": 1.0, "shield_recharge_rate": 20.0})
	_hit(healing, 50.0)
	await _secs(0.5)
	var held: bool = is_equal_approx(healing.shield, 50.0)
	await _secs(2.0)
	_check(held and healing.shield > 50.0, "с настройкой восстановления щит возвращается после паузы (%.0f)" % healing.shield)
	await _clear()
	var scaled = _enemy("gunner", ENEMY_POS, {"shield_capacity": 100.0}, 3.0)
	_check(is_equal_approx(scaled.max_shield, 300.0), "щит растёт с уровнем зоны вместе со здоровьем")
	var shielded: EnemyModifier = load("res://data/content/modifiers/shielded.tres")
	var prefixed = _enemy("chaser", ENEMY_POS + Vector3(5.0, 0.0, 0.0), {}, 1.0, shielded)
	_check(shielded in _config.data.enemy_modifiers.modifiers and is_equal_approx(prefixed.max_shield, shielded.shield_share * prefixed.get_max_health()) and prefixed.get_display_name().begins_with(tr(shielded.name_key)), "префикс «Щитоносный» даёт щит в доле здоровья и виден в названии")
	await _clear()
