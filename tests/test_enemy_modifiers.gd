@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Модификаторы врагов, префиксы (№92). Бросок префикса (шанс зоны, самая ранняя зона, веса, выключатель), применение к врагу
## (здоровье, урон, размер модели вместе с телом, название, оттенок, броня, скорость), особенности (восстановление после паузы,
## ярость при низком здоровье, взрыв при гибели), награда за модифицированных, запрет префиксов у элитных и боссов.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_enemy_modifiers.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.
## Классы врагов и игрока называть по имени тут нельзя (они тянут автозагрузки): тип сверяется по get_script().get_global_name().

const PLAYER_POS: Vector3 = Vector3(0.0, 0.05, 15.0)
const ENEMY_POS: Vector3 = Vector3(0.0, 0.05, 0.0)

var _fails: int = 0
var _room: Node
var _player
var _config
var _settings: EnemyModifierSettings
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _secs(seconds: float) -> void:
	await _frames(int(seconds * 120.0))


func _type_of(node: Object) -> String:
	return node.get_script().get_global_name() if node != null and node.get_script() != null else ""


func _modifier(key: String) -> EnemyModifier:
	return load("res://data/content/modifiers/%s.tres" % key)


func _reset_player(pos: Vector3 = PLAYER_POS) -> void:
	if _player.is_dead:
		_player.respawn(pos, 0.0)
	_player.global_position = pos
	_player.velocity = Vector3.ZERO
	_player.rotation.y = 0.0
	_player.set_look_pitch(0.0)
	_player.set_health(_player.max_health)


func _clear() -> void:
	for node: Node in get_nodes_in_group(&"enemies"):
		node.free()
	for child: Node in _room.get_children():
		var kind: String = _type_of(child)
		if kind == "Pickup" or kind == "ItemPickup" or kind == "BlastEffect" or kind == "ExplosiveBarrel" or kind == "DamageNumber":
			child.free()
	await _frames(2)


# Враг из сцены в точке, с префиксом или без. Настройки копируются с малой дальностью обзора: враг стоит на месте и не атакует,
# поэтому здоровье и награда зависят только от самого теста.
func _enemy(scene_name: String, modifier: EnemyModifier, pos: Vector3 = ENEMY_POS, health_scale: float = 1.0):
	var enemy = (load("res://enemies/%s.tscn" % scene_name) as PackedScene).instantiate()
	enemy.settings = enemy.settings.duplicate()
	enemy.settings.aggro_range = 0.5
	enemy.health_scale = health_scale
	if modifier != null:
		enemy.apply_modifier(modifier)
	_room.add_child(enemy)
	enemy.global_position = pos
	return enemy


func _hit(enemy, amount: float) -> bool:
	var info: DamageInfo = DamageInfo.create(amount, false, enemy.global_position + Vector3(0.0, 1.0, 0.0))
	info.apply_vulnerability = false
	return enemy.take_hit(info)


func _initialize() -> void:
	create_timer(600.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	_config = root.get_node("Config")
	_settings = _config.data.enemy_modifiers
	_rng.seed = 92
	root.get_node("Progress").reset()
	_room = (load("res://rooms/test_room.tscn") as PackedScene).instantiate()
	_room.get_node("Enemies").free()
	_room.get_node("Dummies").queue_free()
	root.add_child(_room)
	await _frames(10)
	_player = _room.get_node("Player")
	# Замеры здоровья без щита: он впитывал бы урон (щиты проверяет test_shields).
	root.get_node("Inventory").shield = null
	await _run()
	print("=== FAILS: ", _fails)
	quit(_fails)


func _run() -> void:
	print("--- Бросок префикса")
	var texts_ok: bool = _settings.modifiers.size() >= 6
	for modifier: EnemyModifier in _settings.modifiers:
		texts_ok = texts_ok and tr(modifier.name_key) != modifier.name_key
	_check(_settings.enabled and texts_ok, "префиксы включены, у всех (%d) есть название в таблице переводов" % _settings.modifiers.size())
	var chances_ok: bool = is_equal_approx(_settings.chance_for_zone(1), _settings.chance_base) and _settings.chance_for_zone(2) > _settings.chance_for_zone(1) and is_equal_approx(_settings.chance_for_zone(99), _settings.chance_max)
	_check(chances_ok, "шанс растёт с зоной (%.2f -> %.2f) и упирается в предел %.2f" % [_settings.chance_for_zone(1), _settings.chance_for_zone(2), _settings.chance_max])
	var rolls: int = 6000
	var modified: int = 0
	var early_ok: bool = true
	for i: int in rolls:
		var picked: EnemyModifier = _settings.roll(_rng, 1)
		if picked != null:
			modified += 1
			early_ok = early_ok and picked.min_zone <= 1
	var share: float = float(modified) / float(rolls)
	_check(absf(share - _settings.chance_for_zone(1)) < 0.025 and early_ok, "в первой зоне префикс у %.1f%% врагов (ждали %.0f%%), поздних префиксов нет" % [share * 100.0, _settings.chance_for_zone(1) * 100.0])
	var seen: Dictionary = {}
	var late_modified: int = 0
	for i: int in rolls:
		var picked: EnemyModifier = _settings.roll(_rng, 8)
		if picked != null:
			seen[picked.name_key] = int(seen.get(picked.name_key, 0)) + 1
			late_modified += 1
	_check(seen.size() == _settings.modifiers.size() and absf(float(late_modified) / float(rolls) - _settings.chance_for_zone(8)) < 0.03, "в поздней зоне выпадают все %d префиксов, доля %.1f%%" % [seen.size(), float(late_modified) / float(rolls) * 100.0])
	var off: EnemyModifierSettings = _settings.duplicate()
	off.enabled = false
	var any_when_off: bool = false
	for i: int in 500:
		any_when_off = any_when_off or off.roll(_rng, 8) != null
	_check(not any_when_off, "выключатель enabled=false: префиксов нет")

	print("--- Применение: Громила")
	await _clear()
	_reset_player()
	var brute: EnemyModifier = _modifier("brute")
	var plain = _enemy("chaser", null)
	var big = _enemy("chaser", brute, Vector3(10.0, 0.05, 0.0))
	await _frames(3)
	_check(is_equal_approx(big.get_max_health(), plain.get_max_health() * brute.health_mult) and big.health == big.get_max_health(), "здоровье x%.1f (%.0f -> %.0f), здоровье полное" % [brute.health_mult, plain.get_max_health(), big.get_max_health()])
	_check(is_equal_approx(big.damage_scale, plain.damage_scale * brute.damage_mult), "урон врага по игроку x%.2f" % brute.damage_mult)
	_check(is_equal_approx(big.scale.x, brute.model_scale) and is_equal_approx(big.scale.y, brute.model_scale) and plain.scale == Vector3.ONE, "модель крупнее: масштаб %.2f, у обычного 1.0" % big.scale.x)
	var space: PhysicsDirectSpaceState3D = _room.get_world_3d().direct_space_state
	var reach_plain: float = _body_reach(space, plain.global_position)
	var reach_big: float = _body_reach(space, big.global_position)
	_check(absf(reach_plain - 0.45) < 0.03 and absf(reach_big - 0.45 * brute.model_scale) < 0.04, "и тело крупнее: радиус столкновения %.2f против %.2f м" % [reach_big, reach_plain])
	_check(big.get_display_name() == "%s %s" % [tr(brute.name_key), tr(plain.settings.name_key)] and plain.get_display_name() == tr(plain.settings.name_key), "название над целью «%s», у обычного «%s»" % [big.get_display_name(), plain.get_display_name()])
	var plain_color: Color = plain.get("_material").albedo_color
	var big_color: Color = big.get("_material").albedo_color
	var color_gap: float = absf(plain_color.r - big_color.r) + absf(plain_color.g - big_color.g) + absf(plain_color.b - big_color.b)
	_check(color_gap > 0.05, "оттенок модели отличается от обычного (разница %.2f)" % color_gap)
	var big_walk_before: Vector3 = big.global_position
	await _secs(0.5)
	_check(big.global_position.distance_to(big_walk_before) < 0.5 and big.is_on_floor(), "крупный враг стоит на полу и не проваливается или улетает (y=%.2f)" % big.global_position.y)
	_check(plain.loot_chance_multiplier() == 1.0 and is_equal_approx(big.loot_chance_multiplier(), brute.drop_mult), "шансы лута x%.1f (у обычного x1.0)" % brute.drop_mult)

	print("--- Характеристики")
	await _clear()
	var iron: EnemyModifier = _modifier("ironclad")
	var armored = _enemy("chaser", iron, ENEMY_POS, 20.0)
	var bare = _enemy("chaser", null, Vector3(10.0, 0.05, 0.0), 20.0)
	await _frames(3)
	var armored_before: float = armored.health
	var bare_before: float = bare.health
	_hit(armored, 100.0)
	_hit(bare, 100.0)
	_check(is_equal_approx(armored_before - armored.health, 100.0 * iron.damage_taken_mult) and is_equal_approx(bare_before - bare.health, 100.0), "Броненосец получает x%.2f урона (-%.0f вместо -100)" % [iron.damage_taken_mult, armored_before - armored.health])
	var fast: EnemyModifier = _modifier("runner")
	var swift = _enemy("chaser", fast, Vector3(-10.0, 0.05, 0.0))
	await _frames(3)
	_check(is_equal_approx(swift.get_speed_multiplier(), fast.speed_mult) and bare.get_speed_multiplier() == 1.0, "Скороход быстрее: x%.2f (у обычного 1.0)" % swift.get_speed_multiplier())
	swift.apply_element(CombatEnums.Element.FROST, 10.0)
	_check(is_equal_approx(swift.get_speed_multiplier(), fast.speed_mult * _config.data.elements.frost_speed_multiplier), "и замедление морозом складывается с ним (x%.2f)" % swift.get_speed_multiplier())

	print("--- Особенность: восстановление")
	await _clear()
	var regen: EnemyModifier = _modifier("regenerator")
	var healer = _enemy("chaser", regen)
	await _frames(3)
	var healer_max: float = healer.get_max_health()
	_hit(healer, healer_max * 0.5)
	var hurt: float = healer.health
	await _secs(regen.regen_delay * 0.5)
	_check(is_equal_approx(healer.health, hurt), "пока идёт пауза после попадания (%.1f с), не лечится" % regen.regen_delay)
	await _secs(regen.regen_delay * 0.5 + 2.0)
	var expected_gain: float = healer_max * regen.regen_per_second * 1.8
	_check(healer.health > hurt + expected_gain and healer.health < healer_max, "после паузы лечится: +%.0f за 2 с (около %.0f в секунду)" % [healer.health - hurt, healer_max * regen.regen_per_second])
	_hit(healer, 1.0)
	var rehurt: float = healer.health
	await _secs(regen.regen_delay * 0.6)
	_check(is_equal_approx(healer.health, rehurt), "новое попадание снова запускает паузу")
	var dormant_healer = _enemy("chaser", null, Vector3(8.0, 0.05, 0.0))
	await _frames(2)
	_hit(dormant_healer, 20.0)
	var dormant_hurt: float = dormant_healer.health
	await _secs(regen.regen_delay + 1.0)
	_check(dormant_healer.health == dormant_hurt, "у врага без префикса здоровье само не растёт")

	print("--- Особенность: ярость")
	await _clear()
	var rage: EnemyModifier = _modifier("berserk")
	var fury = _enemy("chaser", rage)
	await _frames(3)
	var fury_max: float = fury.get_max_health()
	var calm_damage: float = fury.damage_scale
	_check(not fury.enraged and is_equal_approx(fury.get_speed_multiplier(), rage.speed_mult), "здоровый Берсерк спокоен")
	_hit(fury, fury_max * (1.0 - rage.enrage_below) + 1.0)
	await _frames(4)
	_check(fury.health < fury_max * rage.enrage_below and fury.enraged and is_equal_approx(fury.damage_scale, calm_damage * rage.enrage_damage_mult) and is_equal_approx(fury.get_speed_multiplier(), rage.speed_mult * rage.enrage_speed_mult), "ниже %.0f%% здоровья ярость: урон x%.2f, скорость x%.2f" % [rage.enrage_below * 100.0, rage.enrage_damage_mult, fury.get_speed_multiplier()])
	fury.heal(fury_max)
	await _frames(4)
	_check(not fury.enraged and is_equal_approx(fury.damage_scale, calm_damage), "вылеченный успокаивается, урон вернулся")

	print("--- Особенность: взрыв при гибели")
	await _clear()
	var bomb: EnemyModifier = _modifier("bomber")
	var bomber = _enemy("chaser", bomb)
	await _frames(3)
	_reset_player(Vector3(1.0, 0.05, 0.0))
	await _frames(3)
	var barrel = load("res://run/props/explosive_barrel.gd").create(load("res://data/content/props/barrels/explosive.tres"), _config.data.props, 1.0)
	_room.add_child(barrel)
	barrel.global_position = Vector3(-2.0, 0.6, 0.0)
	var bystander = _enemy("chaser", null, Vector3(0.0, 0.05, -2.0))
	await _frames(3)
	var bystander_before: float = bystander.health
	var player_before: int = _player.health
	var killed: bool = _hit(bomber, 1.0e9)
	await _frames(3)
	var player_lost: int = player_before - _player.health
	_check(killed and bomber.is_dead and player_lost > 0 and player_lost <= int(ceil(bomb.death_blast_damage * bomber.damage_scale)) + 1, "гибель Подрывника рядом ранит игрока (-%d из %.0f)" % [player_lost, bomb.death_blast_damage])
	_check(bystander.health == bystander_before, "соседние враги от взрыва не страдают")
	_check(is_instance_valid(barrel) and not barrel.is_queued_for_deletion(), "и бочку он не взрывает")
	await _clear()
	var far_bomber = _enemy("chaser", bomb)
	await _frames(3)
	_reset_player(Vector3(bomb.death_blast_radius + 3.0, 0.05, 0.0))
	await _frames(3)
	_hit(far_bomber, 1.0e9)
	await _frames(3)
	_check(_player.health == _player.max_health, "за радиусом взрыва (%.0f м) игрок цел" % bomb.death_blast_radius)
	await _clear()
	_reset_player()

	print("--- Награда")
	var progress = root.get_node("Progress")
	progress.reset()
	var reward_mod: EnemyModifier = _modifier("berserk")
	var rich = _enemy("chaser", reward_mod)
	await _frames(3)
	var xp_before: int = progress.xp
	var level_before: int = progress.level
	_hit(rich, 1.0e9)
	await _frames(2)
	var xp_gain: int = progress.xp - xp_before
	var money_found: Array = []
	for child: Node in _room.get_children():
		if _type_of(child) == "Pickup" and child.kind == 0:
			money_found.append(child.amount)
	var base_xp: int = rich.settings.xp_reward
	_check(progress.level == level_before and xp_gain == roundi(float(base_xp) * reward_mod.reward_mult), "опыт x%.1f: +%d вместо +%d" % [reward_mod.reward_mult, xp_gain, base_xp])
	var money_ok: bool = money_found.size() == 1 and money_found[0] >= float(rich.settings.money_min) * reward_mod.reward_mult - 1.0 and money_found[0] <= float(rich.settings.money_max) * reward_mod.reward_mult + 1.0
	_check(money_ok, "деньги x%.1f: %s (было бы %d-%d)" % [reward_mod.reward_mult, str(money_found), rich.settings.money_min, rich.settings.money_max])
	await _clear()
	progress.reset()

	print("--- Элитные и боссы")
	var elite_settings: EnemySettings = load("res://data/content/enemies/elite.tres")
	var boss_settings: EnemySettings = load("res://data/content/enemies/boss.tres")
	var plain_settings: EnemySettings = load("res://data/content/enemies/chaser.tres")
	_check(not elite_settings.allows_modifier and not boss_settings.allows_modifier and plain_settings.allows_modifier, "у элитного и босса префиксы запрещены в данных, у обычного врага разрешены")


# Расстояние от центра врага до поверхности его тела по лучу вдоль X с высоты груди (слой врагов).
func _body_reach(space: PhysicsDirectSpaceState3D, center: Vector3) -> float:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(center + Vector3(3.0, 0.9, 0.0), center + Vector3(0.0, 0.9, 0.0), 4)
	var hit: Dictionary = space.intersect_ray(query)
	if hit.is_empty():
		return -1.0
	return (hit["position"] as Vector3).x - center.x
