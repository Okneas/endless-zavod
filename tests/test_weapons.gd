@warning_ignore_start("untyped_declaration")
extends SceneTree
## ТЕСТ: Составное оружие: каталог частей, производители, качество, генерация, характеристики, название,
## сборка модели, слоты и смена оружия, особенности аксессуара, отладочная выдача.
## Запуск: godot --headless --path <проект> --fixed-fps 120 --script res://tests/test_weapons.gd
## Простой скрипт без фреймворка: печатает PASS/FAIL по каждой проверке и «=== FAILS: N», выходит с кодом N.
## Ожидаемые значения берутся из ресурсов (.tres), поэтому правки чисел в Inspector тесты не ломают.

const SAMPLE_COUNT: int = 400

var _fails: int = 0
var _settings: WeaponGenerationSettings
var _generator: WeaponGenerator
var _always_optic: WeaponGenerator
var _never_optic: WeaponGenerator
var _catalog: WeaponCatalog
var _room: Node
var _player
var _weapon
var _progress
var _shot_count: int = 0
var _hit_count: int = 0


func _check(cond: bool, msg: String) -> void:
	print(("PASS  " if cond else "FAIL  ") + msg)
	if not cond:
		_fails += 1


func _info(msg: String) -> void:
	print("INFO  " + msg)


func _frames(n: int) -> void:
	for i: int in n:
		await physics_frame


func _secs(seconds: float) -> void:
	await _frames(ceili(seconds * float(Engine.physics_ticks_per_second)))


func _initialize() -> void:
	create_timer(600.0).timeout.connect(func() -> void:
		print("TIMEOUT")
		quit(2))
	await process_frame
	_progress = root.get_node("Progress")
	_settings = load("res://data/content/balance/weapon_generation.tres")
	_generator = WeaponGenerator.new(_settings)
	_catalog = _generator.catalog
	# Копии настроек с общим шансом оптики 0 и 1: проверки не зависят от того, какой шанс выставил автор.
	var always: WeaponGenerationSettings = _settings.duplicate()
	always.optic_chance = 1.0
	_always_optic = WeaponGenerator.new(always, _catalog)
	var never: WeaponGenerationSettings = _settings.duplicate()
	never.optic_chance = 0.0
	_never_optic = WeaponGenerator.new(never, _catalog)
	_test_data()
	_test_generation()
	_test_sights()
	_test_stats()
	_test_families()
	_test_names()
	_test_model()
	await _test_slots()
	await _test_features_in_play()
	await _test_akimbo()
	await _test_arc()
	print("=== FAILS: ", _fails)
	quit(_fails)


func _rng(seed_value: int = 12345) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


# Часть заданного вида, производителя и типа, первый вариант или второй (v).
func _variant(part_type: int, maker: Manufacturer, type: int, v: int = 0) -> WeaponPart:
	return _catalog.get_variants(part_type, maker, type)[v]


func _maker(id: String) -> Manufacturer:
	return load("res://data/content/manufacturers/%s.tres" % id)


# Собирает оружие вручную из первых вариантов частей данного производителя.
func _build(type: int, makers: Dictionary, v: int = 0) -> WeaponInstance:
	var instance: WeaponInstance = WeaponInstance.new()
	instance.settings = _settings
	for part_type: int in [WeaponPart.PartType.BODY, WeaponPart.PartType.BARREL, WeaponPart.PartType.GRIP, WeaponPart.PartType.MAGAZINE, WeaponPart.PartType.STOCK]:
		if part_type == WeaponPart.PartType.STOCK and not _settings.stock_types.has(type):
			continue
		var maker: Manufacturer = makers.get(part_type, makers["default"])
		instance.parts.append(PartInstance.create(_variant(part_type, maker, type, v), 0))
	return instance


# --- Данные и каталог.
func _test_data() -> void:
	print("--- Данные: каталог, производители, качество")
	_check(_settings.manufacturers.size() == 5, "в настройках генерации 5 производителей (№70): %d" % _settings.manufacturers.size())
	_check(_settings.weapon_types.size() == 8 and _settings.slot_count == 4, "8 типов оружия (пистолеты, револьверы, акимбо, ПП, дробовики, винтовки, полуавтоматы, снайперки) и 4 слота (%d, %d)" % [_settings.weapon_types.size(), _settings.slot_count])
	var scale: QualityScale = _settings.quality_scale
	_check(scale.tiers.size() == 5, "в шкале качества 5 ступеней")
	var ascending: bool = true
	for i: int in range(1, scale.tiers.size()):
		if scale.tiers[i].modifier_count < scale.tiers[i - 1].modifier_count or scale.tiers[i].accessory_feature_count < scale.tiers[i - 1].accessory_feature_count:
			ascending = false
	_check(ascending, "число модификаторов и особенностей аксессуара не убывает с качеством")
	_check(scale.tiers[0].accessory_feature_count >= 1 and scale.tiers[scale.tiers.size() - 1].accessory_feature_count >= 2, "у низших ступеней одна особенность, у высшей две")
	var untranslated: PackedStringArray = []
	for tier: QualityTier in scale.tiers:
		if tr(tier.name_key) == tier.name_key:
			untranslated.append(tier.name_key)
	var max_mods: int = scale.tiers[scale.tiers.size() - 1].modifier_count
	for maker: Manufacturer in _settings.manufacturers:
		if tr(maker.name_key) == maker.name_key or tr(maker.description_key) == maker.description_key:
			untranslated.append(maker.name_key)
		_check(maker.modifier_pool.size() >= max_mods, "%s: в пуле модификаторов не меньше, чем у высшего качества (%d из %d)" % [tr(maker.name_key), maker.modifier_pool.size(), max_mods])
		for modifier: PartModifier in maker.modifier_pool:
			if tr(modifier.name_key) == modifier.name_key or modifier.min_value > modifier.max_value:
				untranslated.append(modifier.name_key)
	for feature: PartFeature in _settings.accessory_features:
		if tr(feature.name_key) == feature.name_key or tr(feature.description_key) == feature.description_key:
			untranslated.append(feature.name_key)
	for prefix_key: String in _settings.prefix_keys:
		for suffix: String in ["_M", "_F", "_N"]:
			if tr(prefix_key + suffix) == prefix_key + suffix:
				untranslated.append(prefix_key + suffix)
	_check(untranslated.is_empty(), "названия качества, производителей, модификаторов, особенностей и префиксов есть в таблице переводов %s" % str(untranslated))

	# Каждому производителю и типу достаточно вариантов (в диздоке минимум 2).
	var shortages: PackedStringArray = []
	for maker: Manufacturer in _settings.manufacturers:
		_check(not maker.weapon_types.is_empty(), "%s: задана специализация (%d типов оружия)" % [tr(maker.name_key), maker.weapon_types.size()])
		for type: int in maker.weapon_types:
			if not _settings.weapon_types.has(type):
				shortages.append("%s делает тип вне настроек: %s" % [maker.name_key, CombatEnums.WeaponType.keys()[type]])
				continue
			var needed: Array = [WeaponPart.PartType.BODY, WeaponPart.PartType.BARREL, WeaponPart.PartType.GRIP, WeaponPart.PartType.MAGAZINE]
			if _settings.stock_types.has(type):
				needed.append(WeaponPart.PartType.STOCK)
			for part_type: int in needed:
				if _catalog.get_variants(part_type, maker, type).size() < 2:
					shortages.append("%s/%s/%s" % [maker.name_key, CombatEnums.WeaponType.keys()[type], WeaponPart.PartType.keys()[part_type]])
		if _catalog.get_variants(WeaponPart.PartType.ACCESSORY, maker, maker.weapon_types[0]).size() < 2:
			shortages.append(maker.name_key + "/ACCESSORY")
	_check(shortages.is_empty(), "у каждого производителя минимум 2 варианта каждой части для каждого типа его специализации %s" % str(shortages))
	# Тип делают минимум два производителя, иначе части не смешиваются; части чужих типов в выдачу не идут.
	var thin: PackedStringArray = []
	for type: int in _settings.weapon_types:
		var count: int = 0
		for maker: Manufacturer in _settings.manufacturers:
			if WeaponCatalog.makes(maker, type):
				count += 1
		if count < 2:
			thin.append(CombatEnums.WeaponType.keys()[type])
	_check(thin.is_empty(), "каждый из 8 типов делают минимум два производителя (иначе смешивать нечего) %s" % str(thin))
	var disabled_ok: bool = true
	for maker: Manufacturer in _settings.manufacturers:
		for type: int in _settings.weapon_types:
			if not WeaponCatalog.makes(maker, type) and not _catalog.get_variants(WeaponPart.PartType.BODY, maker, type).is_empty():
				disabled_ok = false
	_check(disabled_ok, "корпуса типов вне специализации производителя в каталог выдачи не попадают")
	# Таблица уязвимостей: у каждого класса врагов среди выпадающих типов есть и плюс, и минус.
	var table: VulnerabilityTable = load("res://data/content/balance/vulnerability_table.tres")
	var coverage: PackedStringArray = []
	for entry: ClassVulnerability in table.entries:
		var plus: int = 0
		var minus: int = 0
		for type: int in _settings.weapon_types:
			plus += 1 if entry.plus_types.has(type) else 0
			minus += 1 if entry.minus_types.has(type) else 0
		if plus == 0 or minus == 0:
			coverage.append(CombatEnums.EnemyClass.keys()[entry.enemy_class])
	_check(coverage.is_empty(), "у каждого класса врагов среди выпадающих типов оружия есть и плюс, и минус таблицы уязвимостей %s" % str(coverage))
	_check(_catalog.parts.size() >= 200, "в каталоге %d частей" % _catalog.parts.size())

	# Данные частей: названия, модель, подбор, прицел.
	var problems: PackedStringArray = []
	var ids: Dictionary = {}
	for part: WeaponPart in _catalog.parts:
		if tr(part.name_key) == part.name_key:
			problems.append("name " + part.name_key)
		if part.model_size == Vector3.ZERO:
			problems.append("model " + part.resource_path)
		if part.part_type != WeaponPart.PartType.BODY:
			for word_key: String in part.name_words:
				for suffix: String in ["_M", "_F", "_N"]:
					if tr(word_key + suffix) == word_key + suffix:
						problems.append("word " + word_key + suffix)
		else:
			ids[part.name_key] = true
			if not _settings.weapon_types.has(part.weapon_type) or part.base_damage <= 0.0 or part.base_fire_rate <= 0.0 or part.base_magazine_size <= 0:
				problems.append("body " + part.resource_path)
			if part.weapon_type == CombatEnums.WeaponType.AKIMBO:
				if part.has_optic():
					problems.append("akimbo has optic " + part.resource_path)
			elif not part.has_optic() or part.optic_aim_zoom <= part.aim_zoom or part.optic_aim_anchor_position.y <= part.aim_anchor_position.y:
				problems.append("optic data " + part.resource_path)
		if part.signature != null and tr(part.signature.name_key) == part.signature.name_key:
			problems.append("signature " + part.signature.name_key)
	_check(problems.is_empty(), "части: названия и слова переведены, модели заданы, корпуса заполнены %s" % str(problems.slice(0, 5)))
	var bodies: int = 0
	for part: WeaponPart in _catalog.parts:
		if part.part_type == WeaponPart.PartType.BODY:
			bodies += 1
	_check(ids.size() == bodies, "названия всех %d корпусов разные" % bodies)
	_check(_settings.optic_feature != null and tr(_settings.optic_feature.name_key) != _settings.optic_feature.name_key, "особенность «Оптический прицел» есть и переведена")
	# Части без производителя (стартовые и ваши отладочные) в случайную выдачу не попадают.
	var starter_in: bool = false
	for part: WeaponPart in _catalog.parts:
		if part.resource_path.contains("starter_") or part.resource_path.contains("accessory_acid"):
			starter_in = true
	_check(not starter_in, "стартовые и отладочные части (без производителя) не попадают в каталог")


# --- Генерация: инварианты на выборке.
func _test_generation() -> void:
	print("--- Генерация (%d случайных видов оружия)" % SAMPLE_COUNT)
	var rng: RandomNumberGenerator = _rng()
	var bad: PackedStringArray = []
	var maker_seen: Dictionary = {}
	var quality_seen: Dictionary = {}
	var type_seen: Dictionary = {}
	var uniform: int = 0
	var with_accessory: int = 0
	var scale: QualityScale = _settings.quality_scale
	var differing_quality: int = 0
	var names: Dictionary = {}
	for n: int in SAMPLE_COUNT:
		var w: WeaponInstance = _generator.generate(rng, 5)
		if w == null:
			bad.append("null")
			continue
		var type: int = w.get_weapon_type()
		type_seen[type] = true
		if w.level != 5:
			bad.append("level")
		if w.get_quality() != w.get_body().quality:
			bad.append("quality")
		for needed: int in [WeaponPart.PartType.BODY, WeaponPart.PartType.BARREL, WeaponPart.PartType.GRIP, WeaponPart.PartType.MAGAZINE]:
			var count: int = 0
			for instance: PartInstance in w.parts:
				if instance.part.part_type == needed:
					count += 1
			if count != 1:
				bad.append("part count " + str(needed))
		var stock: PartInstance = w.get_part(WeaponPart.PartType.STOCK)
		if (stock != null) != _settings.stock_types.has(type):
			bad.append("stock")
		var accessory: PartInstance = w.get_part(WeaponPart.PartType.ACCESSORY)
		if accessory != null:
			with_accessory += 1
		var first_maker: Manufacturer = w.parts[0].part.manufacturer
		var same_maker: bool = true
		var first_quality: int = w.parts[0].quality
		var same_quality: bool = true
		for instance: PartInstance in w.parts:
			var part: WeaponPart = instance.part
			if not WeaponCatalog.fits(part, type):
				bad.append("fits " + part.resource_path)
			if not WeaponCatalog.makes(part.manufacturer, type):
				bad.append("specialization " + part.resource_path)
			if not _settings.manufacturers.has(part.manufacturer):
				bad.append("maker")
			maker_seen[str(part.part_type) + part.manufacturer.name_key] = true
			quality_seen[instance.quality] = true
			if part.manufacturer != first_maker:
				same_maker = false
			if instance.quality != first_quality:
				same_quality = false
			var tier: QualityTier = scale.tiers[instance.quality]
			if instance.modifiers.size() != mini(tier.modifier_count, part.manufacturer.modifier_pool.size()):
				bad.append("modifier count")
			var used: Dictionary = {}
			for rolled: RolledModifier in instance.modifiers:
				if not part.manufacturer.modifier_pool.has(rolled.modifier) or used.has(rolled.modifier):
					bad.append("modifier pool")
				used[rolled.modifier] = true
				if rolled.value < rolled.modifier.min_value - 0.0006 or rolled.value > rolled.modifier.max_value + 0.0006:
					bad.append("modifier value")
			if part.part_type == WeaponPart.PartType.ACCESSORY:
				if instance.features.size() != mini(tier.accessory_feature_count, _settings.accessory_features.size()):
					bad.append("feature count")
				var elements: int = 0
				var kinds: Dictionary = {}
				for feature: PartFeature in instance.features:
					if not _settings.accessory_features.has(feature) or kinds.has(feature):
						bad.append("feature pool")
					kinds[feature] = true
					if feature.kind == CombatEnums.FeatureKind.ELEMENT:
						elements += 1
				if elements > 1:
					bad.append("two elements")
			elif not instance.features.is_empty():
				bad.append("features outside accessory")
		if same_maker:
			uniform += 1
		if not same_quality:
			differing_quality += 1
		var stats: WeaponStats = w.compute_stats()
		if not (stats.damage > 0.0 and stats.fire_rate > 0.0 and stats.magazine_size >= 1 and stats.reload_time > 0.0 and stats.weapon_range > 0.0 and stats.aim_zoom >= 1.0 and stats.pellets >= 1):
			bad.append("stats")
		var title: String = w.get_display_name()
		names[title] = true
		if not title.ends_with(tr(w.get_body().part.name_key)) or title.begins_with(" ") or title.contains("  "):
			bad.append("name shape")
		var words: int = 0
		for instance: PartInstance in w.parts:
			if instance.name_word != "":
				words += 1
				if not instance.part.name_words.has(instance.name_word):
					bad.append("word pool")
		if words > _settings.max_part_words:
			bad.append("too many words")
		if w.prefix != "" and not _settings.prefix_keys.has(w.prefix):
			bad.append("prefix")
	_check(bad.is_empty(), "инварианты выдержаны: типы, части, совместимость, модификаторы из пула, особенности, название %s" % str(bad.slice(0, 5)))
	_check(type_seen.size() == _settings.weapon_types.size(), "выпали все %d типов оружия" % type_seen.size())
	_check(quality_seen.size() == scale.tiers.size(), "выпали все %d ступеней качества" % quality_seen.size())
	var all_makers: bool = true
	for part_type: int in [WeaponPart.PartType.BODY, WeaponPart.PartType.BARREL, WeaponPart.PartType.GRIP, WeaponPart.PartType.MAGAZINE]:
		for maker: Manufacturer in _settings.manufacturers:
			if not maker_seen.has(str(part_type) + maker.name_key):
				all_makers = false
	_check(all_makers, "у каждой части выпадали все 5 производителей")
	_check(float(uniform) / float(SAMPLE_COUNT) < 0.1, "производитель каждой части независим: все части одного производителя только у %d из %d" % [uniform, SAMPLE_COUNT])
	_check(differing_quality > SAMPLE_COUNT / 2, "качество у частей независимое: у %d из %d оружий части разного качества" % [differing_quality, SAMPLE_COUNT])
	var share: float = float(with_accessory) / float(SAMPLE_COUNT)
	_check(absf(share - _settings.accessory_chance) < 0.08, "аксессуар есть у %.0f%% оружия (шанс %.0f%%)" % [share * 100.0, _settings.accessory_chance * 100.0])
	_check(names.size() > SAMPLE_COUNT / 4, "названия различаются: %d разных на %d оружий" % [names.size(), SAMPLE_COUNT])
	_info("пример названий: %s" % ", ".join(names.keys().slice(0, 6)))

	# Заданный тип.
	var forced_rng: RandomNumberGenerator = _rng(7)
	var forced_ok: bool = true
	for i: int in 40:
		if _generator.generate(forced_rng, 1, CombatEnums.WeaponType.SNIPER).get_weapon_type() != CombatEnums.WeaponType.SNIPER:
			forced_ok = false
	_check(forced_ok, "заданный тип оружия соблюдается")

	# Производитель отдела: шанс 1 даёт только его части, шанс 0 даёт равномерную смесь.
	var department: Manufacturer = _maker("udarnik")
	var always: WeaponGenerationSettings = _settings.duplicate()
	always.department_manufacturer_chance = 1.0
	var gen_always: WeaponGenerator = WeaponGenerator.new(always, _catalog)
	var never: WeaponGenerationSettings = _settings.duplicate()
	never.department_manufacturer_chance = 0.0
	var gen_never: WeaponGenerator = WeaponGenerator.new(never, _catalog)
	var rng2: RandomNumberGenerator = _rng(99)
	var only_dept: bool = true
	var dept_share_total: int = 0
	var parts_total: int = 0
	for i: int in 200:
		# Только типы специализации производителя отдела: чужие типы он не делает.
		var dept_type: int = department.weapon_types[i % department.weapon_types.size()]
		for instance: PartInstance in gen_always.generate(rng2, 1, dept_type, department).parts:
			if instance.part.manufacturer != department:
				only_dept = false
		for instance: PartInstance in gen_never.generate(rng2, 1, dept_type, department).parts:
			parts_total += 1
			if instance.part.manufacturer == department:
				dept_share_total += 1
	_check(only_dept, "шанс производителя отдела 100%%: все части от «%s»" % tr(department.name_key))
	var dept_share: float = float(dept_share_total) / float(parts_total)
	_check(dept_share > 0.15 and dept_share < 0.55, "шанс производителя отдела 0%%: доля его частей %.0f%% (случайная смесь производителей типа)" % (dept_share * 100.0))

	# Повторяемость: один сид даёт то же оружие.
	var a: WeaponInstance = _generator.generate(_rng(555), 3)
	var b: WeaponInstance = _generator.generate(_rng(555), 3)
	_check(a.get_display_name() == b.get_display_name() and is_equal_approx(a.compute_stats().damage, b.compute_stats().damage) and a.parts.size() == b.parts.size(), "один сид даёт одно и то же оружие")


# --- Прицел корпуса: оптика с шансом у любого производителя.
func _test_sights() -> void:
	print("--- Прицел корпуса")
	var rng: RandomNumberGenerator = _rng(77)
	var bonus_makers: Array[Manufacturer] = []
	for maker: Manufacturer in _settings.manufacturers:
		if maker.optic_chance_bonus > 0.0:
			bonus_makers.append(maker)
	_check(not bonus_makers.is_empty() and _settings.optic_chance > 0.0, "в данных есть общий шанс оптики (%.0f%%) и производитель с добавкой (%s)" % [_settings.optic_chance * 100.0, tr(bonus_makers[0].name_key) if not bonus_makers.is_empty() else "-"])
	var always_bad: int = 0
	var never_bad: int = 0
	var guaranteed_bad: int = 0
	var zoom_bad: int = 0
	var feature_bad: int = 0
	var anchor_bad: int = 0
	for i: int in 300:
		var forced: WeaponInstance = _always_optic.generate(rng, 1)
		# Оптика ставится на любой корпус, у которого она есть; у акимбо её нет совсем.
		if forced.get_body().part.has_optic() != (forced.get_sight() == CombatEnums.SightType.OPTIC):
			always_bad += 1
		var plain: WeaponInstance = _never_optic.generate(rng, 1)
		var maker: Manufacturer = plain.get_manufacturer()
		var chance: float = clampf(maker.optic_chance_bonus, 0.0, 1.0)
		if chance <= 0.0 and plain.get_sight() == CombatEnums.SightType.OPTIC:
			never_bad += 1
		if chance >= 1.0 and plain.get_body().part.has_optic() and plain.get_sight() != CombatEnums.SightType.OPTIC:
			guaranteed_bad += 1
		for w: WeaponInstance in [forced, plain]:
			var body: WeaponPart = w.get_body().part
			var optic: bool = w.get_sight() == CombatEnums.SightType.OPTIC
			if not is_equal_approx(w.compute_stats().aim_zoom, body.optic_aim_zoom if optic else body.aim_zoom):
				zoom_bad += 1
			if not w.get_aim_anchor().is_equal_approx(body.optic_aim_anchor_position if optic else body.aim_anchor_position):
				anchor_bad += 1
			if w.get_features().has(_settings.optic_feature) != optic:
				feature_bad += 1
	_check(always_bad == 0, "общий шанс 100%%: оптика на каждом корпусе любого из %d производителей" % _settings.manufacturers.size())
	_check(never_bad == 0, "общий шанс 0: оптики нет у производителей без добавки шанса")
	_check(guaranteed_bad == 0, "производитель с добавкой 100%: оптика всегда, даже при общем шансе 0")
	_check(zoom_bad == 0 and anchor_bad == 0, "приближение и точка прицела берутся от выпавшего прицела, а не от производителя")
	_check(feature_bad == 0, "особенность «Оптический прицел» показывается только у оружия с оптикой")
	# Настоящий шанс из данных.
	var optic_total: int = 0
	var sample_total: int = 0
	var per_maker: Dictionary = {}
	for i: int in 600:
		var w: WeaponInstance = _generator.generate(rng, 1)
		var maker: Manufacturer = w.get_manufacturer()
		var optic: bool = w.get_sight() == CombatEnums.SightType.OPTIC
		if optic:
			per_maker[maker] = true
		if maker.optic_chance_bonus <= 0.0 and w.get_body().part.has_optic():
			sample_total += 1
			optic_total += 1 if optic else 0
	var share: float = float(optic_total) / float(maxi(sample_total, 1))
	_check(absf(share - _settings.optic_chance) < 0.07, "у производителей без добавки оптика у %.0f%% корпусов (шанс %.0f%%)" % [share * 100.0, _settings.optic_chance * 100.0])
	_check(per_maker.size() == _settings.manufacturers.size(), "оптика выпадала у корпусов всех %d производителей" % per_maker.size())
	# Оба прицела видны на модели и в описании частей.
	var optic_weapon: WeaponInstance = _always_optic.generate(rng, 1)
	var iron_weapon: WeaponInstance = _never_optic.generate(rng, 1)
	while iron_weapon.get_sight() == CombatEnums.SightType.OPTIC:
		iron_weapon = _never_optic.generate(rng, 1)
	_check(optic_weapon.describe_parts()[0].contains(tr(_settings.optic_feature.name_key)) and not iron_weapon.describe_parts()[0].contains(tr(_settings.optic_feature.name_key)), "оптика отмечена в описании корпуса")


# --- Характеристики.
func _test_stats() -> void:
	print("--- Характеристики: уровень, уклон производителей, модификаторы, особенности")
	var smg: int = CombatEnums.WeaponType.SMG
	var baza: Manufacturer = _maker("baza")
	var udarnik: Manufacturer = _maker("udarnik")
	var oitp: Manufacturer = _maker("oitp")
	var plain: WeaponInstance = _build(smg, {"default": baza})
	var base_stats: WeaponStats = plain.compute_stats()
	var body: WeaponPart = plain.get_body().part
	# Уровень.
	var high: WeaponInstance = _build(smg, {"default": baza})
	high.level = 11
	_check(is_equal_approx(high.compute_stats().damage / base_stats.damage, 1.0 + _settings.damage_per_level * 10.0), "уровень 11 даёт урон x%.2f против уровня 1 (%.0f%% за уровень)" % [high.compute_stats().damage / base_stats.damage, _settings.damage_per_level * 100.0])
	_check(is_equal_approx(high.compute_stats().fire_rate, base_stats.fire_rate) and high.compute_stats().magazine_size == base_stats.magazine_size, "уровень не меняет темп и магазин")
	# Уклон: меняем производителя только у корпуса.
	var rifle: int = CombatEnums.WeaponType.ASSAULT_RIFLE
	var rifle_stats: WeaponStats = _build(rifle, {"default": baza}).compute_stats()
	var tilt_body: WeaponInstance = _build(rifle, {"default": baza, WeaponPart.PartType.BODY: udarnik})
	var ts: WeaponStats = tilt_body.compute_stats()
	_check(is_equal_approx(ts.damage / rifle_stats.damage, udarnik.damage_mult / baza.damage_mult) and is_equal_approx(ts.fire_rate / rifle_stats.fire_rate, udarnik.fire_rate_mult / baza.fire_rate_mult), "корпус даёт уклон урона и темпа: x%.3f и x%.3f (ожидалось x%.3f и x%.3f)" % [ts.damage / rifle_stats.damage, ts.fire_rate / rifle_stats.fire_rate, udarnik.damage_mult / baza.damage_mult, udarnik.fire_rate_mult / baza.fire_rate_mult])
	_check(is_equal_approx(ts.spread_deg, rifle_stats.spread_deg) and is_equal_approx(ts.weapon_range, rifle_stats.weapon_range) and ts.magazine_size == rifle_stats.magazine_size, "корпус не меняет характеристики других частей (разброс, дальность, магазин)")
	# Уклон дула: разброс и дальность, но не урон. Сравниваем с дулом ОИТП без фирменной особенности.
	var oitp_barrel: WeaponPart = _variant(WeaponPart.PartType.BARREL, oitp, smg, 1)
	var baza_barrel: WeaponPart = _variant(WeaponPart.PartType.BARREL, baza, smg, 1)
	var swapped: WeaponInstance = _build(smg, {"default": baza}, 1)
	var reference: WeaponStats = swapped.compute_stats()
	for i: int in swapped.parts.size():
		if swapped.parts[i].part.part_type == WeaponPart.PartType.BARREL:
			swapped.parts[i] = PartInstance.create(oitp_barrel, 0)
	var ss: WeaponStats = swapped.compute_stats()
	var module_spread: float = 1.0
	if oitp_barrel.signature != null:
		for change: PartModifier in oitp_barrel.signature.stat_changes:
			if change.stat == CombatEnums.Stat.SPREAD:
				module_spread *= PartModifier.factor_for(change.stat, (change.min_value + change.max_value) * 0.5)
	_check(is_equal_approx(ss.spread_deg / reference.spread_deg, oitp.spread_mult / baza.spread_mult * module_spread) and is_equal_approx(ss.damage, reference.damage), "дуло даёт уклон разброса: x%.3f (ожидалось x%.3f), урон не меняется" % [ss.spread_deg / reference.spread_deg, oitp.spread_mult / baza.spread_mult * module_spread])
	_check(baza_barrel.manufacturer == baza and oitp_barrel.manufacturer == oitp, "варианты частей принадлежат своим производителям")
	# Уклон не удваивается: все части одного производителя дают его множитель ровно один раз.
	var all_baza_spread: float = body.base_spread_deg * baza.spread_mult
	for instance: PartInstance in plain.parts:
		all_baza_spread *= instance.part.spread_mult
	_check(is_equal_approx(base_stats.spread_deg, all_baza_spread), "уклон производителя применяется один раз, а не по числу частей (разброс %.3f)" % base_stats.spread_deg)
	# Модификаторы.
	var modded: WeaponInstance = _build(smg, {"default": baza})
	var barrel_instance: PartInstance = modded.get_part(WeaponPart.PartType.BARREL)
	var changes: Array = [[CombatEnums.Stat.DAMAGE, 0.1], [CombatEnums.Stat.RELOAD_TIME, 0.1], [CombatEnums.Stat.CRIT_CHANCE, 0.02]]
	barrel_instance.modifiers.clear()
	for change: Array in changes:
		var modifier: PartModifier = PartModifier.new()
		modifier.stat = change[0]
		barrel_instance.modifiers.append(RolledModifier.create(modifier, change[1]))
	var ms: WeaponStats = modded.compute_stats()
	_check(is_equal_approx(ms.damage / base_stats.damage, 1.1) and is_equal_approx(ms.reload_time / base_stats.reload_time, 0.9) and is_equal_approx(ms.crit_chance - base_stats.crit_chance, 0.02), "модификаторы: урон x1.1, перезарядка x0.9 (меньше лучше), крит +2%%")
	# Особенности аксессуара.
	var featured: WeaponInstance = _build(smg, {"default": baza})
	var accessory: PartInstance = PartInstance.create(_variant(WeaponPart.PartType.ACCESSORY, baza, smg), 0)
	for feature: PartFeature in _settings.accessory_features:
		accessory.features.append(feature)
	featured.parts.append(accessory)
	var fs: WeaponStats = featured.compute_stats()
	var expected_element: int = CombatEnums.Element.NONE
	var slide: float = 0.0
	var air: float = 0.0
	var melee: float = 0.0
	for feature: PartFeature in _settings.accessory_features:
		if feature.kind == CombatEnums.FeatureKind.ELEMENT and expected_element == CombatEnums.Element.NONE:
			expected_element = feature.element
		slide += feature.value if feature.kind == CombatEnums.FeatureKind.SLIDE_DAMAGE else 0.0
		air += feature.value if feature.kind == CombatEnums.FeatureKind.AIR_DAMAGE else 0.0
		melee += feature.value if feature.kind == CombatEnums.FeatureKind.MELEE_DAMAGE else 0.0
	_check(fs.element == expected_element and expected_element != CombatEnums.Element.NONE, "особенность «стихия» даёт оружию стихию %s" % CombatEnums.Element.keys()[fs.element])
	_check(is_equal_approx(fs.slide_damage_bonus, slide) and is_equal_approx(fs.air_damage_bonus, air) and is_equal_approx(fs.melee_damage_bonus, melee) and slide > 0.0 and air > 0.0 and melee > 0.0, "бонусы урона в подкате (+%.0f%%), в воздухе (+%.0f%%) и в ближнем бою (+%.0f%%)" % [fs.slide_damage_bonus * 100.0, fs.air_damage_bonus * 100.0, fs.melee_damage_bonus * 100.0])
	_check(is_equal_approx(fs.damage, base_stats.damage) and base_stats.element == CombatEnums.Element.NONE and base_stats.slide_damage_bonus == 0.0, "без аксессуара особенностей нет, а аксессуар урон сам не меняет")
	# Фирменная особенность: дульный тормоз «Ударника» снижает отдачу.
	var brake_barrel: WeaponPart = _variant(WeaponPart.PartType.BARREL, udarnik, rifle, 0)
	var plain_barrel: WeaponPart = _variant(WeaponPart.PartType.BARREL, baza, rifle, 0)
	var with_brake: WeaponInstance = _build(rifle, {"default": baza})
	var without_brake: WeaponInstance = _build(rifle, {"default": baza})
	for i: int in with_brake.parts.size():
		if with_brake.parts[i].part.part_type == WeaponPart.PartType.BARREL:
			with_brake.parts[i] = PartInstance.create(brake_barrel, 0)
			without_brake.parts[i] = PartInstance.create(plain_barrel, 0)
	var recoil_factor: float = with_brake.compute_stats().recoil_deg / without_brake.compute_stats().recoil_deg
	var brake: float = 1.0
	for change: PartModifier in brake_barrel.signature.stat_changes:
		if change.stat == CombatEnums.Stat.RECOIL:
			brake *= PartModifier.factor_for(change.stat, (change.min_value + change.max_value) * 0.5)
	_check(is_equal_approx(recoil_factor, brake) and brake < 1.0, "фирменный дульный тормоз «Ударника» снижает отдачу: x%.2f" % recoil_factor)
	# Дробовик: дробины из корпуса.
	var shotgun: WeaponInstance = _build(CombatEnums.WeaponType.SHOTGUN, {"default": baza})
	_check(shotgun.compute_stats().pellets > 1 and base_stats.pellets == 1, "у дробовика несколько дробин (%d), у ПП одна" % shotgun.compute_stats().pellets)
	# Стартовое оружие через ту же формулу, что и определение.
	var definition: WeaponDefinition = load("res://data/content/parts/starter_pistol.tres")
	var starter: WeaponInstance = WeaponInstance.from_definition(definition, 1, 1, _settings)
	var from_definition: WeaponStats = definition.compute_stats()
	_check(is_equal_approx(starter.compute_stats().damage, from_definition.damage) and starter.compute_stats().magazine_size == from_definition.magazine_size, "стартовое оружие и определение дают одни характеристики")
	_check(starter.get_manufacturer() == null and starter.get_part(WeaponPart.PartType.ACCESSORY) == null and starter.get_quality() == 1, "стартовый пистолет: без производителя и аксессуара, качество по настройке")
	_check(starter.get_display_name() == tr(definition.name_key), "название стартового пистолета берётся из шаблона")


# --- Семейства оружия и новые виды (№72).
func _test_families() -> void:
	print("--- Семейства: револьверы, акимбо, дробовики, винтовки")
	var shotgun_families: Dictionary = {}
	var shotgun_bad: PackedStringArray = []
	var sniper_family: Dictionary = {}
	for part: WeaponPart in _catalog.parts:
		if part.part_type != WeaponPart.PartType.BODY:
			continue
		if part.weapon_type == CombatEnums.WeaponType.SHOTGUN:
			shotgun_families[part.family_key] = true
			if part.family_key == "" or tr(part.family_key) == part.family_key or part.base_pellets < 2:
				shotgun_bad.append(part.resource_path)
		if part.weapon_type == CombatEnums.WeaponType.SNIPER:
			sniper_family[part.family_key] = true
	_check(shotgun_bad.is_empty() and shotgun_families.size() >= 3, "дробовики трёх семейств (помповый, двустволка, автоматический): найдено %d, у всех свои дробины и название %s" % [shotgun_families.size(), str(shotgun_bad.slice(0, 3))])
	_check(sniper_family.size() == 1 and not sniper_family.has("") and tr(sniper_family.keys()[0]) != sniper_family.keys()[0], "у снайперок семейство «с затвором» и оно переведено")
	# Имя типа для карточки: семейство, а без семейства название типа.
	var pump: WeaponInstance = null
	for part: WeaponPart in _catalog.parts:
		if part.part_type == WeaponPart.PartType.BODY and part.family_key != "" and part.weapon_type == CombatEnums.WeaponType.SHOTGUN and WeaponCatalog.makes(part.manufacturer, part.weapon_type):
			pump = WeaponInstance.new()
			pump.settings = _settings
			pump.parts.append(PartInstance.create(part, 0))
			break
	_check(pump != null and pump.get_type_name() == tr(pump.get_body().part.family_key), "название типа на карточке дробовика это семейство «%s»" % pump.get_type_name())
	var plain: WeaponInstance = _build(CombatEnums.WeaponType.PISTOL, {"default": _maker("baza")})
	_check(plain.get_type_name() == tr("WEAPON_TYPE_PISTOL"), "у обычного пистолета название типа «%s»" % plain.get_type_name())
	# Новые виды: у каждого есть корпус, приклад только у полуавтомата, парный только акимбо.
	var seen: Dictionary = {}
	for part: WeaponPart in _catalog.parts:
		if part.part_type == WeaponPart.PartType.BODY and WeaponCatalog.makes(part.manufacturer, part.weapon_type):
			seen[part.weapon_type] = true
	_check(seen.size() == 8, "корпуса есть у всех 8 типов (найдено %d)" % seen.size())
	var dual_ok: bool = true
	for part: WeaponPart in _catalog.parts:
		if part.part_type == WeaponPart.PartType.BODY and (part.second_model_offset != Vector3.ZERO) != (part.weapon_type == CombatEnums.WeaponType.AKIMBO):
			dual_ok = false
	_check(dual_ok, "второе оружие в модели только у акимбо")
	var revolver: WeaponInstance = _build(CombatEnums.WeaponType.REVOLVER, {"default": _maker("oitp")})
	var akimbo: WeaponInstance = _build(CombatEnums.WeaponType.AKIMBO, {"default": _maker("baza")})
	var semi: WeaponInstance = _build(CombatEnums.WeaponType.SEMI_AUTO_RIFLE, {"default": _maker("luch")})
	_check(revolver.get_part(WeaponPart.PartType.STOCK) == null and akimbo.get_part(WeaponPart.PartType.STOCK) == null and semi.get_part(WeaponPart.PartType.STOCK) != null, "у револьвера и акимбо нет приклада, у полуавтоматической винтовки есть")
	var all_stats: WeaponStats = akimbo.compute_stats()
	_check(all_stats.weapon_type == CombatEnums.WeaponType.AKIMBO and revolver.compute_stats().weapon_type == CombatEnums.WeaponType.REVOLVER and semi.compute_stats().weapon_type == CombatEnums.WeaponType.SEMI_AUTO_RIFLE, "тип оружия в характеристиках: акимбо, револьвер, полуавтомат (для таблицы уязвимостей)")
	# Модель парного оружия: вторая копия со смещением, второе дуло смещено на то же значение.
	var built: WeaponModelBuilder.Result = WeaponModelBuilder.build(akimbo)
	var offset: Vector3 = akimbo.get_body().part.second_model_offset
	var first: Node3D = built.root.get_node_or_null("First")
	var second: Node3D = built.root.get_node_or_null("Second")
	var identical: bool = first != null and second != null and first.get_child_count() == second.get_child_count()
	if identical:
		for i: int in first.get_child_count():
			var a: MeshInstance3D = first.get_child(i) as MeshInstance3D
			var b: MeshInstance3D = second.get_child(i) as MeshInstance3D
			if a.name != b.name or not a.position.is_equal_approx(b.position) or not (a.mesh as BoxMesh).size.is_equal_approx((b.mesh as BoxMesh).size):
				identical = false
	_check(built.has_second and identical and second.position.is_equal_approx(offset) and built.second_muzzle.is_equal_approx(built.muzzle + offset), "акимбо: два одинаковых ствола (%d деталей, с прицелами), второй смещён на %s" % [first.get_child_count() if first != null else 0, str(offset)])
	_check(first.get_node_or_null("FrontSight") != null and second.get_node_or_null("FrontSight") != null and second.get_node_or_null("RearSightLeft") != null, "у обоих стволов акимбо свой целик и мушка")
	_check(akimbo.get_sight() == CombatEnums.SightType.IRON and not akimbo.get_body().part.has_optic(), "у акимбо оптики быть не может")
	built.root.free()
	# Пистолет-дробовик «СельхозОборона»: по типу пистолет, но стреляет дробью.
	var pistol_shotguns: Array[WeaponPart] = []
	for part: WeaponPart in _catalog.parts:
		if part.part_type == WeaponPart.PartType.BODY and part.family_key == "FAMILY_PISTOL_SHOTGUN":
			pistol_shotguns.append(part)
	var ps_ok: bool = pistol_shotguns.size() >= 2
	for part: WeaponPart in pistol_shotguns:
		if part.weapon_type != CombatEnums.WeaponType.PISTOL or part.base_pellets < 2 or part.manufacturer != _maker("selhoz") or tr(part.family_key) == part.family_key:
			ps_ok = false
	_check(ps_ok, "у «СельхозОбороны» есть пистолеты-дробовики (%d корпуса): тип пистолет, несколько дробин, семейство переведено" % pistol_shotguns.size())
	var ps_weapon: WeaponInstance = WeaponInstance.new()
	ps_weapon.settings = _settings
	for part_type: int in [WeaponPart.PartType.BODY, WeaponPart.PartType.BARREL, WeaponPart.PartType.GRIP, WeaponPart.PartType.MAGAZINE]:
		var variant: WeaponPart = pistol_shotguns[0] if part_type == WeaponPart.PartType.BODY else _variant(part_type, _maker("selhoz"), CombatEnums.WeaponType.PISTOL)
		ps_weapon.parts.append(PartInstance.create(variant, 0))
	_check(ps_weapon.compute_stats().pellets > 1 and ps_weapon.get_type_name() == tr("FAMILY_PISTOL_SHOTGUN") and ps_weapon.get_part(WeaponPart.PartType.STOCK) == null, "пистолет-дробовик: %d дробин, «%s», без приклада" % [ps_weapon.compute_stats().pellets, ps_weapon.get_type_name()])
	var single: WeaponModelBuilder.Result = WeaponModelBuilder.build(revolver)
	_check(not single.has_second and single.root.get_node_or_null("Second") == null, "у обычного оружия второй модели нет")
	single.root.free()


# --- Название по роду.
func _test_names() -> void:
	print("--- Название: род и порядок слов")
	var genders: Dictionary = {}
	for maker: Manufacturer in _settings.manufacturers:
		for type: int in maker.weapon_types:
			for v: int in 2:
				var part: WeaponPart = _variant(WeaponPart.PartType.BODY, maker, type, v)
				if not genders.has(part.gender):
					genders[part.gender] = part
	_check(genders.size() == 3, "среди корпусов есть все три рода (%d)" % genders.size())
	var prefix: String = _settings.prefix_keys[0]
	for gender: int in genders:
		var body_part: WeaponPart = genders[gender]
		var instance: WeaponInstance = WeaponInstance.new()
		instance.settings = _settings
		instance.parts.append(PartInstance.create(body_part, 0))
		var barrel: PartInstance = PartInstance.create(_variant(WeaponPart.PartType.BARREL, body_part.manufacturer, body_part.weapon_type), 0)
		barrel.name_word = barrel.part.name_words[0]
		instance.parts.append(barrel)
		instance.prefix = prefix
		var suffix: String = ["_M", "_F", "_N"][gender]
		var expected: String = "%s %s %s" % [tr(prefix + suffix), tr(barrel.name_word + suffix), tr(body_part.name_key)]
		_check(instance.get_display_name() == expected, "род %s: «%s» (префикс, слово дула, корпус)" % [["мужской", "женский", "средний"][gender], instance.get_display_name()])
	var forms: Dictionary = {tr(prefix + "_M"): true, tr(prefix + "_F"): true, tr(prefix + "_N"): true}
	_check(forms.size() == 3, "у префикса три разные формы по роду")
	var bare: WeaponInstance = WeaponInstance.new()
	bare.settings = _settings
	bare.parts.append(PartInstance.create(genders[0], 0))
	_check(bare.get_display_name() == tr(genders[0].name_key), "без префикса и слов название это название корпуса")


# --- Модель из частей.
func _test_model() -> void:
	print("--- Модель из частей")
	var rng: RandomNumberGenerator = _rng(31)
	var bad: PackedStringArray = []
	var generators: Array = [_generator, _always_optic, _never_optic]
	for i: int in 90:
		var w: WeaponInstance = generators[i % 3].generate(rng, 1)
		var built: WeaponModelBuilder.Result = WeaponModelBuilder.build(w)
		var body: WeaponPart = w.get_body().part
		var barrel: PartInstance = w.get_part(WeaponPart.PartType.BARREL)
		var expected_muzzle: Vector3 = body.mount_barrel + Vector3(0.0, 0.0, -barrel.part.model_size.z)
		if not built.muzzle.is_equal_approx(expected_muzzle):
			bad.append("muzzle")
		if not built.aim_anchor.is_equal_approx(w.get_aim_anchor()):
			bad.append("anchor")
		var gun: Node3D = built.root.get_node("First") if built.has_second else built.root
		var boxes: int = gun.get_child_count()
		# Корпус, ствол, рукоять, магазин и прицел, у типов с прикладом ещё приклад, у аксессуара своя коробка.
		var minimum: int = w.parts.size() + (3 if w.get_sight() == CombatEnums.SightType.IRON else 4)
		if boxes < minimum:
			bad.append("boxes %d < %d" % [boxes, minimum])
		if w.get_sight() == CombatEnums.SightType.OPTIC and (gun.get_node_or_null("OpticTop") == null or gun.get_node_or_null("FrontSight") != null):
			bad.append("optic frame")
		if w.get_sight() == CombatEnums.SightType.IRON and (gun.get_node_or_null("FrontSight") == null or gun.get_node_or_null("OpticTop") != null):
			bad.append("iron sight")
		# Прицельная линия свободна: ни одна коробка корпуса не перекрывает точку прицела.
		for child: Node in gun.get_children():
			var mesh_node: MeshInstance3D = child as MeshInstance3D
			if mesh_node == null or child.name.begins_with("Optic") or child.name.contains("Sight"):
				continue
			var half: Vector3 = (mesh_node.mesh as BoxMesh).size * 0.5
			var delta: Vector3 = (built.aim_anchor - mesh_node.position).abs()
			# Линия прицела идёт вдоль оси Z: коробка перекрывает её, если накрывает точку прицела по X и Y.
			if delta.x < half.x and delta.y < half.y:
				bad.append("blocks aim " + child.name)
		built.root.free()
	_check(bad.is_empty(), "модель собирается из частей, дуло и прицел на месте, прицельная линия свободна (90 видов, оба прицела) %s" % str(bad.slice(0, 5)))


# --- Слоты, смена оружия, модель в руках.
func _load_room() -> void:
	_room = (load("res://rooms/test_room.tscn") as PackedScene).instantiate()
	_room.get_node("Enemies").free()
	root.add_child(_room)


func _release_all() -> void:
	for a: String in ["move_forward", "move_back", "move_left", "move_right", "jump", "crouch", "fire", "aim", "reload", "melee", "weapon_slot_1", "weapon_slot_2", "weapon_slot_3", "weapon_slot_4", "debug_give_weapon"]:
		Input.action_release(a)


func _tap(action: String, frames: int = 3) -> void:
	Input.action_press(action)
	await _frames(frames)
	Input.action_release(action)


func _occupied() -> int:
	var count: int = 0
	for slot_instance in _weapon.slots:
		if slot_instance != null:
			count += 1
	return count


func _instance_of(type: int, level: int = 1) -> WeaponInstance:
	return _generator.generate(_rng(1000 + type), level, type)


func _test_slots() -> void:
	print("--- Слоты и смена оружия")
	_load_room()
	await _frames(10)
	_player = _room.get_node("Player")
	_weapon = _player.get_weapon()
	var shooting: ShootingSettings = _weapon.shooting
	var swap_wait: float = shooting.swap_time + 0.2
	_check(_weapon.slots.size() == _settings.slot_count and _occupied() == 1 and _weapon.active_slot == 0, "%d слота, занят один: стартовый пистолет в слоте 1" % _weapon.slots.size())
	var starter: WeaponInstance = _weapon.slots[0]
	_check(starter.follows_player_level and starter.get_part(WeaponPart.PartType.ACCESSORY) == null and _weapon.get_display_name() == tr("WEAPON_STARTER_PISTOL"), "стартовое оружие: «%s», растёт вместе с уровнем персонажа, без аксессуара" % _weapon.get_display_name())
	var viewmodel: Node3D = _weapon.get_node("Viewmodel")
	_check(viewmodel.get_node_or_null("Generated") == null and viewmodel.get_node("Body").visible, "у стартового пистолета ручная модель из сцены")
	var default_muzzle: Vector3 = viewmodel.get_node("Muzzle").position
	var default_anchor: Vector3 = viewmodel.get_node("AimAnchor").position

	# Стартовое оружие растёт с уровнем.
	var damage_level_1: float = _weapon.stats.damage
	_progress.level = 6
	_progress.level_changed.emit(6)
	_check(is_equal_approx(_weapon.stats.damage / damage_level_1, 1.0 + _settings.damage_per_level * 5.0), "уровень персонажа 6: урон стартового пистолета x%.2f" % (_weapon.stats.damage / damage_level_1))
	_progress.reset()
	_check(is_equal_approx(_weapon.stats.damage, damage_level_1), "после сброса уровня урон прежний")

	# Выдача в первый пустой слот и смена.
	var sniper: WeaponInstance = _instance_of(CombatEnums.WeaponType.SNIPER)
	var slot: int = _weapon.give_weapon(sniper)
	_check(slot == 1 and _weapon.slots[1] == sniper, "оружие легло в первый пустой слот (%d)" % (slot + 1))
	await _secs(swap_wait)
	_check(_weapon.active_slot == 1 and _weapon.instance == sniper and not _weapon.is_swapping(), "после смены в руках новое оружие «%s»" % _weapon.get_display_name())
	var expected: WeaponStats = sniper.compute_stats()
	_check(is_equal_approx(_weapon.stats.damage, expected.damage) and _weapon.stats.magazine_size == expected.magazine_size and _weapon.ammo == expected.magazine_size and _weapon.stats.weapon_type == CombatEnums.WeaponType.SNIPER, "характеристики и магазин нового оружия: урон %.0f, магазин %d, тип снайперка" % [_weapon.stats.damage, _weapon.ammo])
	var generated: Node3D = viewmodel.get_node_or_null("Generated")
	var body_part: WeaponPart = sniper.get_body().part
	var barrel_part: WeaponPart = sniper.get_part(WeaponPart.PartType.BARREL).part
	_check(generated != null and not viewmodel.get_node("Body").visible, "собранная модель показана, ручная модель скрыта")
	_check(viewmodel.get_node("Muzzle").position.is_equal_approx(body_part.mount_barrel + Vector3(0.0, 0.0, -barrel_part.model_size.z)), "дуло на конце ствола собранной модели")
	_check(viewmodel.get_node("AimAnchor").position.is_equal_approx(sniper.get_aim_anchor()), "точка прицела берётся у корпуса и выпавшего прицела (%s)" % ("оптика" if sniper.get_sight() == CombatEnums.SightType.OPTIC else "целик"))
	# Приближение прицеливания берётся у корпуса нового оружия с учётом выпавшего прицела.
	_weapon.aim_amount = 1.0
	_check(is_equal_approx(_weapon.get_zoom(), expected.aim_zoom), "приближение при прицеливании x%.1f из данных корпуса" % _weapon.get_zoom())
	_weapon.aim_amount = 0.0

	# Патроны у каждого оружия свои, перезарядка прерывается сменой.
	_weapon.ammo = 2
	_weapon.start_reload()
	_check(_weapon.is_reloading, "началась перезарядка")
	await _tap("weapon_slot_1")
	await _secs(swap_wait)
	_check(_weapon.active_slot == 0 and not _weapon.is_reloading and viewmodel.get_node_or_null("Generated") == null and viewmodel.get_node("Body").visible, "клавиша 1 вернула стартовый пистолет, перезарядка прервана, ручная модель на месте")
	_check(viewmodel.get_node("Muzzle").position.is_equal_approx(default_muzzle) and viewmodel.get_node("AimAnchor").position.is_equal_approx(default_anchor), "дуло и прицел стартового пистолета возвращены")
	await _tap("weapon_slot_2")
	await _secs(swap_wait)
	_check(_weapon.active_slot == 1 and _weapon.ammo == 2, "у снайперки остались её 2 патрона после смены туда и обратно (%d)" % _weapon.ammo)

	# Во время смены стрелять нельзя, пустой слот не выбирается.
	_weapon.ammo = _weapon.stats.magazine_size
	await _tap("weapon_slot_1", 2)
	var ammo_in_swap: int = _weapon.ammo
	Input.action_press("fire")
	await _secs(shooting.swap_time * 0.4)
	Input.action_release("fire")
	_check(_weapon.is_swapping(), "началась смена оружия")
	await _secs(swap_wait)
	_check(_weapon.slots[1].ammo == ammo_in_swap, "пока идёт смена, выстрелов нет (патронов %d из %d)" % [_weapon.slots[1].ammo, ammo_in_swap])
	await _tap("weapon_slot_3")
	await _secs(swap_wait)
	_check(_weapon.active_slot == 0, "пустой слот 3 не выбирается")

	# Заполняем слоты и заменяем активный.
	_weapon.give_weapon(_instance_of(CombatEnums.WeaponType.SHOTGUN))
	_weapon.give_weapon(_instance_of(CombatEnums.WeaponType.SMG))
	await _secs(swap_wait)
	_check(_occupied() == 4, "все 4 слота заняты")
	var active_before: WeaponInstance = _weapon.instance
	var replacement: WeaponInstance = _instance_of(CombatEnums.WeaponType.ASSAULT_RIFLE)
	var replaced_slot: int = _weapon.give_weapon(replacement)
	_check(replaced_slot == _weapon.active_slot and _weapon.slots[replaced_slot] == replacement and _weapon.instance == replacement and _weapon.instance != active_before, "при полных слотах новое оружие заменяет активное (слот %d)" % (replaced_slot + 1))

	# Колесо мыши листает по кругу.
	var start_slot: int = _weapon.active_slot
	var next_event: InputEventAction = InputEventAction.new()
	next_event.action = &"weapon_next"
	next_event.pressed = true
	Input.parse_input_event(next_event)
	await _secs(swap_wait)
	_check(_weapon.active_slot == (start_slot + 1) % 4, "колесо вниз: следующий слот (%d -> %d)" % [start_slot + 1, _weapon.active_slot + 1])
	var prev_event: InputEventAction = InputEventAction.new()
	prev_event.action = &"weapon_prev"
	prev_event.pressed = true
	Input.parse_input_event(prev_event)
	await _secs(swap_wait)
	_check(_weapon.active_slot == start_slot, "колесо вверх: предыдущий слот (%d)" % (_weapon.active_slot + 1))
	_weapon.slots[1] = null
	_weapon.active_slot = 0
	_weapon.instance = _weapon.slots[0]
	Input.parse_input_event(next_event)
	await _secs(swap_wait)
	_check(_weapon.active_slot == 2, "пустой слот пропускается: из слота 1 колесо ведёт в слот 3 (%d)" % (_weapon.active_slot + 1))
	_release_all()


func _test_features_in_play() -> void:
	print("--- Особенности в бою, дробины, отладочная выдача")
	_progress.reset()
	await _tap("weapon_slot_1")
	await _secs(_weapon.shooting.swap_time + 0.2)
	var dummy = _room.get_node("Dummies/TargetDummy2")
	var dummy_max: float = dummy.settings.max_health
	# Оружие с особенностями в подкате, в воздухе, в ближнем бою.
	var baza: Manufacturer = _maker("baza")
	var featured: WeaponInstance = _build(CombatEnums.WeaponType.ASSAULT_RIFLE, {"default": baza})
	featured.level = 1
	var accessory: PartInstance = PartInstance.create(_variant(WeaponPart.PartType.ACCESSORY, baza, CombatEnums.WeaponType.ASSAULT_RIFLE), 0)
	for feature: PartFeature in _settings.accessory_features:
		if feature.kind == CombatEnums.FeatureKind.SLIDE_DAMAGE or feature.kind == CombatEnums.FeatureKind.AIR_DAMAGE or feature.kind == CombatEnums.FeatureKind.MELEE_DAMAGE:
			accessory.features.append(feature)
	featured.parts.append(accessory)
	_weapon.give_weapon(featured)
	await _secs(_weapon.shooting.swap_time + 0.2)
	_weapon.stats.crit_chance = 0.0
	_weapon.crit_bonus = 0.0
	var stats: WeaponStats = _weapon.stats
	var point: Vector3 = dummy.global_position + Vector3(0.0, 1.0, 0.0)
	var table: VulnerabilityTable = load("res://data/content/balance/vulnerability_table.tres")
	var vulnerability: float = table.get_multiplier(dummy.enemy_class, stats.weapon_type)
	_weapon.sliding = false
	_weapon.airborne = false
	dummy.health = dummy_max
	_weapon.call("_apply_hit", dummy, point)
	var normal_loss: float = dummy_max - dummy.health
	_check(is_equal_approx(normal_loss, stats.damage * vulnerability), "обычный выстрел: урон %.2f (урон оружия %.2f x уязвимость %.2f)" % [normal_loss, stats.damage, vulnerability])
	_weapon.sliding = true
	dummy.health = dummy_max
	_weapon.call("_apply_hit", dummy, point)
	_check(is_equal_approx((dummy_max - dummy.health) / normal_loss, 1.0 + stats.slide_damage_bonus), "выстрел в подкате: урон x%.2f (бонус +%.0f%%)" % [(dummy_max - dummy.health) / normal_loss, stats.slide_damage_bonus * 100.0])
	_weapon.sliding = false
	_weapon.airborne = true
	dummy.health = dummy_max
	_weapon.call("_apply_hit", dummy, point)
	_check(is_equal_approx((dummy_max - dummy.health) / normal_loss, 1.0 + stats.air_damage_bonus), "выстрел в воздухе: урон x%.2f (бонус +%.0f%%)" % [(dummy_max - dummy.health) / normal_loss, stats.air_damage_bonus * 100.0])
	_weapon.sliding = true
	dummy.health = dummy_max
	_weapon.call("_apply_hit", dummy, point)
	_check(is_equal_approx((dummy_max - dummy.health) / normal_loss, 1.0 + stats.slide_damage_bonus + stats.air_damage_bonus), "подкат и воздух вместе складываются: x%.2f" % ((dummy_max - dummy.health) / normal_loss))
	_weapon.sliding = false
	_weapon.airborne = false
	# Ближний бой.
	_player.global_position = Vector3(0.0, 0.05, 4.0)
	_player.velocity = Vector3.ZERO
	_player.rotation.y = 0.0
	await _secs(0.5)
	var melee = _player.get_node("Melee")
	var melee_damage: float = melee.settings.damage
	dummy.health = dummy_max
	melee.swing()
	_check(is_equal_approx(dummy_max - dummy.health, melee_damage * (1.0 + stats.melee_damage_bonus)), "удар в ближнем бою с аксессуаром: %.0f (удар %.0f, бонус +%.0f%%)" % [dummy_max - dummy.health, melee_damage, stats.melee_damage_bonus * 100.0])
	await _secs(1.0)
	_weapon.give_weapon(_instance_of(CombatEnums.WeaponType.PISTOL))
	await _secs(_weapon.shooting.swap_time + 0.2)
	dummy.health = dummy_max
	melee.swing()
	_check(is_equal_approx(dummy_max - dummy.health, melee_damage), "оружие без аксессуара: удар прежний (%.0f)" % (dummy_max - dummy.health))

	# Дробовик: несколько дробин за выстрел, урон делится, цель получает один суммарный удар.
	var shotgun: WeaponInstance = _instance_of(CombatEnums.WeaponType.SHOTGUN)
	_weapon.give_weapon(shotgun)
	await _secs(_weapon.shooting.swap_time + 0.2)
	_weapon.stats.crit_chance = 0.0
	_weapon.crit_bonus = 0.0
	_weapon.shot_traced.connect(func(_d: Vector3, _e: Vector3, _h: bool) -> void: _shot_count += 1)
	_weapon.hit_confirmed.connect(func(_c: bool, _k: bool) -> void: _hit_count += 1)
	_weapon.stats.spread_deg = 0.01
	_weapon.set("_cooldown", 0.0)
	_weapon.ammo = _weapon.stats.magazine_size
	var camera: Camera3D = _player.get_node("Head/Camera3D")
	_player.global_position = Vector3(0.0, 0.05, 5.0)
	_player.velocity = Vector3.ZERO
	await _secs(0.3)
	var aim_target: Vector3 = dummy.global_position + Vector3(0.0, 0.9, 0.0)
	var to_target: Vector3 = aim_target - camera.global_position
	_player.rotation.y = atan2(-to_target.x, -to_target.z)
	_player.set_look_pitch(atan2(to_target.y, Vector2(to_target.x, to_target.z).length()))
	await _secs(0.2)
	dummy.health = dummy_max
	_shot_count = 0
	_hit_count = 0
	var ammo_before: int = _weapon.ammo
	_clear_numbers()
	_weapon.call("_fire")
	var shotgun_stats: WeaponStats = _weapon.stats
	var shotgun_vulnerability: float = table.get_multiplier(dummy.enemy_class, CombatEnums.WeaponType.SHOTGUN)
	_check(_shot_count == shotgun_stats.pellets and _weapon.ammo == ammo_before - 1, "один выстрел дробовика: %d дробин, один патрон" % _shot_count)
	_check(_hit_count == 1 and is_equal_approx(dummy_max - dummy.health, shotgun_stats.damage * shotgun_vulnerability), "все дробины в цель дают один удар на весь урон %.1f (х%.2f), получено %.1f" % [shotgun_stats.damage, shotgun_vulnerability, dummy_max - dummy.health])
	# Цифра урона на каждую дробину: их число равно числу попавших дробин, в сумме дают урон по цели.
	var numbers: Array = _numbers()
	var shown: int = 0
	for number in numbers:
		shown += int(number.text)
	_check(numbers.size() == shotgun_stats.pellets, "на каждую из %d дробин своя цифра урона (показано %d)" % [shotgun_stats.pellets, numbers.size()])
	var expected_total: float = shotgun_stats.damage * shotgun_vulnerability
	_check(shown == roundi(expected_total), "цифры дробин в сумме дают урон по цели: %d (урон %.1f)" % [shown, expected_total])
	_check(not numbers.is_empty() and numbers[0].font_size < 48, "цифры дробин мельче обычной (%d)" % (numbers[0].font_size if not numbers.is_empty() else 0))
	# Крит бросается на каждую дробину отдельно: при шансе 100% все цифры крит-цвета и урон выше в crit_multiplier раз.
	_clear_numbers()
	_weapon.crit_bonus = 1.0
	dummy.health = dummy_max
	_weapon.set("_cooldown", 0.0)
	_weapon.ammo = _weapon.stats.magazine_size
	_weapon.call("_fire")
	numbers = _numbers()
	var all_crit: bool = not numbers.is_empty()
	for number in numbers:
		if not (is_equal_approx(number.modulate.r, DamageNumber.COLOR_CRIT.r) and is_equal_approx(number.modulate.g, DamageNumber.COLOR_CRIT.g)):
			all_crit = false
	var crit_shown: int = 0
	for number in numbers:
		crit_shown += int(number.text)
	_check(all_crit and numbers.size() == shotgun_stats.pellets and crit_shown == roundi(expected_total * _weapon.shooting.crit_multiplier), "шанс крита 100%%: все %d цифр дробин крит-цвета, в сумме %d" % [numbers.size(), crit_shown])
	_check(is_equal_approx(dummy_max - dummy.health, expected_total * _weapon.shooting.crit_multiplier), "урон крита по всем дробинам x%.1f: %.1f" % [_weapon.shooting.crit_multiplier, dummy_max - dummy.health])
	_weapon.crit_bonus = 0.0
	_player.set_look_pitch(0.0)
	# Оружие с одной пулей показывает одну цифру.
	_clear_numbers()
	_weapon.sliding = false
	_weapon.airborne = false
	var single: WeaponInstance = _build(CombatEnums.WeaponType.PISTOL, {"default": _maker("baza")})
	_weapon.give_weapon(single)
	await _secs(_weapon.shooting.swap_time + 0.2)
	_weapon.stats.crit_chance = 0.0
	dummy.health = dummy_max
	_weapon.call("_apply_hit", dummy, dummy.global_position + Vector3(0.0, 1.0, 0.0))
	_check(_numbers().size() == 1, "оружие с одной пулей: одна цифра урона (%d)" % _numbers().size())

	# Отладочная выдача по клавише: оружие уровня персонажа кладётся в инвентарь, слоты не трогает.
	var inventory: Node = root.get_node("Inventory")
	inventory.clear()
	var before: int = _occupied()
	_progress.level = 4
	await _tap("debug_give_weapon")
	await _frames(3)
	_check(inventory.items.size() == 1 and _occupied() == before, "клавиша G положила оружие в инвентарь, слоты не изменились (занято %d)" % _occupied())
	var given: WeaponInstance = inventory.items[0].weapon if inventory.items.size() > 0 else null
	_check(given != null and given.level == 4 and not given.follows_player_level, "выданное оружие уровня персонажа (%d)" % _progress.level)
	await _tap("debug_give_weapon")
	await _tap("debug_give_weapon")
	await _frames(3)
	_check(inventory.items.size() == 3, "каждое нажатие добавляет оружие в инвентарь (%d)" % inventory.items.size())
	inventory.clear()
	var overlay: Label = _room.get_node("DebugOverlay/Label")
	await _frames(3)
	_check(overlay.text.contains(_weapon.get_display_name()) and overlay.text.contains(tr(_settings.quality_scale.tiers[_weapon.instance.get_quality()].name_key)), "в отладочной надписи название и качество оружия в руках")
	_progress.reset()
	_release_all()


# Цифры урона над мишенями лежат в узле Dummies (родитель мишени).
func _numbers() -> Array:
	var result: Array = []
	for child: Node in _room.get_node("Dummies").get_children():
		if child is DamageNumber:
			result.append(child)
	return result


func _clear_numbers() -> void:
	for number in _numbers():
		number.free()


# Акимбо в руках: выстрелы идут по очереди из двух стволов.
func _test_akimbo() -> void:
	print("--- Акимбо в руках")
	_progress.reset()
	await _tap("weapon_slot_1")
	await _secs(_weapon.shooting.swap_time + 0.2)
	var maker: Manufacturer = _maker("baza")
	var akimbo: WeaponInstance = _build(CombatEnums.WeaponType.AKIMBO, {"default": maker})
	var akimbo_slot: int = _weapon.give_weapon(akimbo)
	await _secs(_weapon.shooting.swap_time + 0.2)
	var offset: Vector3 = akimbo.get_body().part.second_model_offset
	var viewmodel: Node3D = _weapon.get_node("Viewmodel")
	var muzzle: Node3D = viewmodel.get_node("Muzzle")
	_check(viewmodel.get_node("Generated").get_node_or_null("Second") != null, "в руках две модели оружия")
	var main_position: Vector3 = muzzle.position
	var positions: Array[Vector3] = []
	_weapon.stats.crit_chance = 0.0
	for i: int in 4:
		_weapon.set("_cooldown", 0.0)
		_weapon.ammo = _weapon.stats.magazine_size
		_weapon.call("_fire")
		positions.append(muzzle.position)
	_check(positions[0].is_equal_approx(main_position) and positions[1].is_equal_approx(main_position + offset) and positions[2].is_equal_approx(main_position) and positions[3].is_equal_approx(main_position + offset), "выстрелы идут по очереди из правого и левого ствола (смещение дула %s)" % str(offset))
	_check(_weapon.stats.weapon_type == CombatEnums.WeaponType.AKIMBO and _weapon.get_current_spread() > 0.0, "в руках акимбо с общим магазином %d и темпом %.1f выстр/с" % [_weapon.stats.magazine_size, _weapon.stats.fire_rate])
	# Прицеливание: стволы сводятся к середине и наклоняются внутрь, от бедра они на месте и ровные.
	var first: Node3D = viewmodel.get_node("Generated/First")
	var second: Node3D = viewmodel.get_node("Generated/Second")
	var body: WeaponPart = akimbo.get_body().part
	_weapon.aim_amount = 0.0
	_weapon.call("_update_viewmodel")
	_check(second.position.is_equal_approx(body.second_model_offset) and first.rotation.is_zero_approx() and second.rotation.is_zero_approx(), "от бедра стволы разведены на %.2f м и стоят ровно" % absf(second.position.x - first.position.x))
	_weapon.aim_amount = 1.0
	# Отдача от только что сделанных выстрелов сдвигает модель назад: для проверки положения обнуляем её.
	_weapon.set("_kick", 0.0)
	_weapon.call("_update_viewmodel")
	var tilt: float = deg_to_rad(body.dual_aim_tilt_deg)
	_check(second.position.is_equal_approx(body.second_aim_offset) and absf(second.position.x) < absf(body.second_model_offset.x), "в прицеливании стволы сведены к середине: %.2f м вместо %.2f м" % [absf(second.position.x - first.position.x), absf(body.second_model_offset.x)])
	_check(is_equal_approx(first.rotation.z, tilt) and is_equal_approx(second.rotation.z, -tilt) and first.rotation.y > 0.0 and second.rotation.y < 0.0, "в прицеливании стволы наклонены внутрь: крен %.0f° и разворот %.0f° к середине" % [body.dual_aim_tilt_deg, rad_to_deg(first.rotation.y)])
	# Центр экрана приходится на середину между стволами, а не на правый ствол.
	var middle: Vector3 = viewmodel.get_node("AimAnchor").position + second.position * 0.5
	_check(is_equal_approx(viewmodel.position.x, -middle.x) and is_equal_approx(viewmodel.position.z, -_weapon.shooting.aim_eye_distance - middle.z), "в прицеливании модель смещена так, что середина между стволами в центре экрана")
	# Дуло следует за стволом: в прицеливании стреляет из наклонённого ствола.
	_weapon.set("_cooldown", 0.0)
	_weapon.set("_second_next", true)
	_weapon.call("_fire")
	_check(muzzle.position.is_equal_approx(second.position + second.basis * _weapon.get("_gun_muzzle")), "дуло левого ствола в прицеливании следует за наклонённым стволом")
	_weapon.aim_amount = 0.0
	_weapon.call("_update_viewmodel")
	# После смены оружия акимбо снова начинает с правого ствола.
	_weapon.set("_cooldown", 0.0)
	_weapon.call("_fire")
	var after_odd: Vector3 = muzzle.position
	_weapon.switch_to((akimbo_slot + 1) % 4)
	await _secs(_weapon.shooting.swap_time + 0.2)
	_weapon.switch_to(akimbo_slot)
	await _secs(_weapon.shooting.swap_time + 0.2)
	_weapon.set("_cooldown", 0.0)
	_weapon.call("_fire")
	_check(after_odd.is_equal_approx(main_position) and muzzle.position.is_equal_approx(main_position), "после смены оружия акимбо снова начинает с правого ствола")
	_release_all()

# Дуга патронов держится снаружи креста: при большом разбросе уезжает сразу, обратно возвращается плавно.
func _test_arc() -> void:
	print("--- Дуга патронов и крест")
	# Вспышка креста от только что сделанных выстрелов должна догаснуть.
	await _secs(0.5)
	var crosshair = _room.get_node("Hud/Root/Crosshair")
	var arc = crosshair.get_node("AmmoArc")
	var base: float = arc.radius
	var margin: float = arc.clearance_margin
	crosshair.set_spread_pixels(0.0)
	crosshair.set_aim(0.0)
	arc.set_clearance(crosshair.get_outer_radius())
	for i: int in 60:
		arc._process(0.1)
	_check(is_equal_approx(arc.get_current_radius(), base), "спокойный прицел: дуга на своём радиусе %.0f px" % base)
	crosshair.set_spread_pixels(90.0)
	arc.set_clearance(crosshair.get_outer_radius())
	arc._process(0.0)
	var outer: float = crosshair.get_outer_radius()
	_check(arc.get_current_radius() >= outer + margin - 0.001 and arc.get_current_radius() > base, "большой разброс: дуга сразу отъехала на %.0f px (плечи креста до %.0f px)" % [arc.get_current_radius(), outer])
	_check(arc.get_current_radius() - arc.line_width * 0.5 > outer, "плечи креста дугу не перекрывают: между ними %.1f px" % (arc.get_current_radius() - arc.line_width * 0.5 - outer))
	crosshair.set_spread_pixels(0.0)
	arc.set_clearance(crosshair.get_outer_radius())
	arc._process(0.05)
	var step: float = arc.get_current_radius()
	_check(step > base and step < outer + margin, "разброс упал: дуга возвращается плавно, а не прыжком (%.1f px)" % step)
	for i: int in 60:
		arc._process(0.1)
	_check(is_equal_approx(arc.get_current_radius(), base), "через время дуга снова на своём месте")
	# Прицеливание прячет крест: дуга не оставляется далеко из-за невидимых плеч.
	crosshair.set_spread_pixels(90.0)
	crosshair.set_aim(1.0)
	_check(crosshair.get_outer_radius() == 0.0, "в прицеливании крест скрыт и дугу не отодвигает")
	crosshair.set_aim(0.0)
	crosshair.set_spread_pixels(0.0)
