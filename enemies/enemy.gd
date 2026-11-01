class_name Enemy
extends CharacterBody3D
## База всех врагов (02-combat-fps, №38): здоровье, получение урона по таблице уязвимостей,
## эффекты стихий, смерть, награда (опыт, деньги, аптечки). Поведение у наследников
## (chaser, flyer, turret, support): они переопределяют _behavior().
## Данные: EnemySettings (enemies/*.tres, правятся в Inspector у узла).

signal died(enemy: Enemy)

## Сколько секунд враг подсвечивается после попадания.
const FLASH_TIME: float = 0.08
## Как часто (секунды) складывается в одну цифру урон от тока по времени.
const DOT_NUMBER_INTERVAL: float = 0.5
const TINT_ELECTRIC: Color = Color(0.45, 0.7, 1.0)
const TINT_FROST: Color = Color(0.6, 0.95, 1.0)
const TINT_ACID: Color = Color(0.55, 1.0, 0.3)
const TINT_FIRE: Color = Color(1.0, 0.55, 0.2)
## Подсветка врага под барьером щитовика и знак замаха (прыжок, рывок камикадзе).
const TINT_WARD: Color = Color(0.55, 0.45, 1.0)
const TINT_TELEGRAPH: Color = Color(1.0, 0.9, 0.25)
## Оттенок врага, пока цел щит (№93), и вспышка в миг, когда щит пробит.
const TINT_SHIELD: Color = Color(0.4, 0.7, 1.0)
const SHIELD_BREAK_TIME: float = 0.25
## Метка слабого места (№93): светящийся шар на теле. Размер метки относительно радиуса слабого места.
const WEAK_POINT_COLOR: Color = Color(1.0, 0.95, 0.35)
const WEAK_POINT_MARKER_SHARE: float = 0.35

## Настройки врага. Править в Inspector здесь или двойным щелчком по .tres в data/content/enemies/.
@export var settings: EnemySettings

var health: float = 0.0
var is_dead: bool = false
## Знает, где игрок, при любом расстоянии (бой в большой комнате: контроллер комнаты включает это с начала боя).
var always_aggro: bool = false
## Множители здоровья и урона от уровня зоны (срез 7): ставит тот, кто создаёт врага, до add_child.
var health_scale: float = 1.0
var damage_scale: float = 1.0
## Уровень врага равен уровню зоны, в которой он появился (срез 7б): виден над врагом и задаёт силу через health_scale и damage_scale.
var level: int = 1
## Саппорт-щитовик, который сейчас гасит урон по этому врагу (null — никто).
var warded_by: Enemy
## Замах перед сильным действием (0..1): враг мигает, игроку виден знак. Ставят наследники.
var telegraph_amount: float = 0.0
## Враг ещё не появился (№87): скрыт, не двигается и не принимает попаданий, пока светится место его появления. Пока он спит, он
## уже считается живым врагом комнаты, поэтому бой не кончается раньше времени.
var dormant: bool = false
## Боковая полоса подхода к игроку (-1..1, не около нуля): у каждого врага своя, поэтому толпа заходит с разных сторон (№86).
var flank_lane: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Префикс врага (№92): сдвигает характеристики, размер и даёт особенности. Ставится apply_modifier() до add_child.
var modifier: EnemyModifier
## Ярость префикса включилась (здоровье упало ниже порога).
var enraged: bool = false
## Щит врага (№93): урон идёт в него первым, остаток в здоровье. Ёмкость считается в _ready (тип, уровень зоны и префикс).
var shield: float = 0.0
var max_shield: float = 0.0

var _base_damage_scale: float = 1.0
var _since_hit: float = 999.0
var _player: Player
var _awake_layer: int = 0
var _flash_left: float = 0.0
var _shield_break_left: float = 0.0
var _weak_marker: MeshInstance3D
# Оставшееся время эффектов стихий (секунды) и урон тока в секунду.
var _acid_left: float = 0.0
var _electric_left: float = 0.0
var _electric_dps: float = 0.0
var _frost_left: float = 0.0
var _fire_left: float = 0.0
var _dot_pending: float = 0.0
var _dot_number_left: float = 0.0
var _material: StandardMaterial3D
var _base_color: Color

@onready var _body: MeshInstance3D = $Body


func _ready() -> void:
	assert(settings != null, "У врага не назначены настройки (EnemySettings)")
	add_to_group(&"enemies")
	rng.randomize()
	flank_lane = rng.randf_range(0.4, 1.0) * (1.0 if rng.randf() < 0.5 else -1.0)
	health = get_max_health()
	max_shield = get_max_shield()
	shield = max_shield
	# Материал свой у каждого врага, иначе подсветка одного мигала бы у всех.
	_material = (_body.mesh.material as StandardMaterial3D).duplicate()
	_body.material_override = _material
	_base_color = _material.albedo_color
	if modifier != null and modifier.tint_amount > 0.0:
		_base_color = _base_color.lerp(modifier.tint, modifier.tint_amount)
	_build_weak_marker()


## Усыпить врага до появления (true) или разбудить (false).
func set_dormant(value: bool) -> void:
	if value == dormant:
		return
	dormant = value
	visible = not value
	if value:
		_awake_layer = collision_layer
		collision_layer = 0
	else:
		collision_layer = _awake_layer
	set_physics_process(not value and not is_dead)


## Название врага для плашки цели над прицелом (№86).
func get_display_name() -> String:
	if modifier != null:
		return tr("ENEMY_MODIFIED_NAME").format({"prefix": tr(modifier.name_key), "name": tr(settings.name_key)})
	return tr(settings.name_key)


## Ставит префикс (№92): здоровье, урон, размер модели. Вызывать до add_child: здоровье считается в _ready.
func apply_modifier(new_modifier: EnemyModifier) -> void:
	modifier = new_modifier
	health_scale *= modifier.health_mult
	damage_scale *= modifier.damage_mult
	_base_damage_scale = damage_scale
	scale = Vector3.ONE * modifier.model_scale


## Во сколько раз префикс увеличивает шансы выпадения деталей, гранат и хлама.
func loot_chance_multiplier() -> float:
	return modifier.drop_mult if modifier != null else 1.0


## Здоровье врага с учётом уровня зоны.
func get_max_health() -> float:
	return settings.max_health * health_scale


## Ёмкость щита врага (№93): щит типа, растущий с уровнем зоны вместе со здоровьем, плюс доля здоровья от префикса.
func get_max_shield() -> float:
	var value: float = settings.shield_capacity * health_scale
	if modifier != null:
		value += modifier.shield_share * get_max_health()
	return value


## Есть ли у врага слабое место (№93).
func has_weak_point() -> bool:
	return settings.weak_point_multiplier > 1.0 and settings.weak_point_radius > 0.0


## Центр слабого места в мире: смещение из настроек поворачивается и растёт вместе с врагом.
func get_weak_point_center() -> Vector3:
	return to_global(settings.weak_point_offset)


## Радиус слабого места в мире.
func get_weak_point_world_radius() -> float:
	return settings.weak_point_radius * global_basis.get_scale().x


## Во сколько раз выстрел в точку point сильнее обычного: множитель слабого места, если точка внутри его шара, иначе 1.
func get_weak_point_multiplier_at(point: Vector3) -> float:
	if dormant or is_dead or not has_weak_point():
		return 1.0
	if point.distance_to(get_weak_point_center()) <= get_weak_point_world_radius():
		return settings.weak_point_multiplier
	return 1.0


func _process(delta: float) -> void:
	if is_dead:
		return
	_flash_left = maxf(_flash_left - delta, 0.0)
	_shield_break_left = maxf(_shield_break_left - delta, 0.0)
	var color: Color = _base_color
	if shield > 0.0:
		color = color.lerp(TINT_SHIELD, 0.3)
	if _electric_left > 0.0:
		color = color.lerp(TINT_ELECTRIC, 0.55)
	elif _frost_left > 0.0:
		color = color.lerp(TINT_FROST, 0.55)
	elif _acid_left > 0.0:
		color = color.lerp(TINT_ACID, 0.5)
	elif _fire_left > 0.0:
		color = color.lerp(TINT_FIRE, 0.5)
	if get_damage_taken_multiplier() < 1.0:
		color = color.lerp(TINT_WARD, 0.5)
	if telegraph_amount > 0.0:
		color = color.lerp(TINT_TELEGRAPH, telegraph_amount * (0.55 + 0.45 * sin(Time.get_ticks_msec() * 0.03)))
	if _shield_break_left > 0.0:
		color = color.lerp(TINT_SHIELD.lerp(Color.WHITE, 0.6), _shield_break_left / SHIELD_BREAK_TIME)
	if _flash_left > 0.0:
		color = color.lerp(Color.WHITE, _flash_left / FLASH_TIME)
	_material.albedo_color = color


func _physics_process(delta: float) -> void:
	if is_dead:
		return
	_update_status(delta)
	if is_dead:
		return
	_since_hit += delta
	_update_modifier(delta)
	_update_shield(delta)
	var player: Player = _get_player()
	_behavior(delta, player if player != null and not player.is_dead else null)


## Поведение конкретного типа. player: живой игрок или null (игрока нет или он погиб).
func _behavior(_delta: float, _player_or_null: Player) -> void:
	pass


## Получить урон. Возвращает true, если враг уничтожен этим попаданием.
func take_hit(info: DamageInfo) -> bool:
	if is_dead:
		return false
	var amount: float = info.amount * get_damage_taken_multiplier()
	if info.apply_vulnerability:
		amount *= Config.data.vulnerabilities.get_multiplier(settings.enemy_class, info.weapon_type)
	if _acid_left > 0.0:
		amount *= Config.data.elements.acid_damage_taken_multiplier
	_flash_left = FLASH_TIME
	_since_hit = 0.0
	var had_shield: bool = shield > 0.0
	var through: float = _absorb_by_shield(amount, info.element)
	DamageNumber.spawn_hit(get_parent(), info, amount, had_shield and through <= 0.0)
	_lose_health(through)
	if is_dead:
		return true
	# Пока щит цел, он прикрывает от эффектов стихий: они цепляются после пробития (ток зато бьёт по щиту сильнее).
	if info.element != CombatEnums.Element.NONE and shield <= 0.0:
		apply_element(info.element, amount)
	return false


# Щит впитывает урон первым (№93). Ток съедает его быстрее (electric_shield_multiplier), остаток урона после пробития идёт в здоровье.
# Возвращает урон, дошедший до здоровья.
func _absorb_by_shield(amount: float, element: CombatEnums.Element) -> float:
	if shield <= 0.0:
		return amount
	var multiplier: float = Config.data.elements.electric_shield_multiplier if element == CombatEnums.Element.ELECTRIC else 1.0
	var needed: float = amount * multiplier
	if needed < shield:
		shield -= needed
		return 0.0
	var covered: float = shield / multiplier
	shield = 0.0
	_shield_break_left = SHIELD_BREAK_TIME
	return maxf(amount - covered, 0.0)


# Восстановление щита: после shield_recharge_delay без попаданий набирает shield_recharge_rate (с ростом по уровню зоны) в секунду.
func _update_shield(delta: float) -> void:
	if max_shield <= 0.0 or shield >= max_shield or settings.shield_recharge_rate <= 0.0 or _since_hit < settings.shield_recharge_delay:
		return
	shield = minf(shield + settings.shield_recharge_rate * health_scale * delta, max_shield)


# Метка слабого места: светящийся шар на поверхности тела, виден всегда.
func _build_weak_marker() -> void:
	if not has_weak_point():
		return
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = WEAK_POINT_COLOR
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = settings.weak_point_radius * WEAK_POINT_MARKER_SHARE
	mesh.height = mesh.radius * 2.0
	mesh.material = material
	_weak_marker = MeshInstance3D.new()
	_weak_marker.name = "WeakPoint"
	_weak_marker.mesh = mesh
	_weak_marker.position = settings.weak_point_offset
	_weak_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_weak_marker)


## Накладывает эффект стихии. hit_amount: урон попавшего выстрела (от него считается ток).
func apply_element(element: CombatEnums.Element, hit_amount: float) -> void:
	var elements: ElementSettings = Config.data.elements
	match element:
		CombatEnums.Element.ACID:
			_acid_left = elements.acid_duration
		CombatEnums.Element.ELECTRIC:
			_electric_left = elements.electric_duration
			_electric_dps = hit_amount * elements.electric_dps_fraction
		CombatEnums.Element.FROST:
			_frost_left = elements.frost_duration
		CombatEnums.Element.FIRE:
			_fire_left = elements.fire_duration


## Во сколько раз игрок снижает урон по этому врагу: барьер щитовика почти обнуляет его (EnemySettings.ward_damage_taken).
func get_damage_taken_multiplier() -> float:
	var armor: float = modifier.damage_taken_mult if modifier != null else 1.0
	if warded_by != null and is_instance_valid(warded_by) and not warded_by.is_dead and warded_by.is_warding(self):
		return warded_by.settings.ward_damage_taken * armor
	return armor


## Гасит ли этот враг (щитовик) урон по target прямо сейчас.
func is_warding(_target: Enemy) -> bool:
	return false


## Летит ли враг (нужно директору: летающие появляются выше земли и им не нужен пол под ногами).
func is_flier() -> bool:
	return false


func heal(amount: float) -> void:
	if is_dead:
		return
	health = minf(health + amount, get_max_health())


## Множитель скорости: мороз замедляет.
func get_speed_multiplier() -> float:
	var multiplier: float = Config.data.elements.frost_speed_multiplier if _frost_left > 0.0 else 1.0
	if modifier != null:
		multiplier *= modifier.speed_mult * (modifier.enrage_speed_mult if enraged else 1.0)
	return multiplier


func is_electrified() -> bool:
	return _electric_left > 0.0


func is_acidified() -> bool:
	return _acid_left > 0.0


func is_frozen() -> bool:
	return _frost_left > 0.0


func is_burning() -> bool:
	return _fire_left > 0.0


func _get_player() -> Player:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(&"player") as Player
	return _player


func _update_status(delta: float) -> void:
	_acid_left = maxf(_acid_left - delta, 0.0)
	_frost_left = maxf(_frost_left - delta, 0.0)
	_fire_left = maxf(_fire_left - delta, 0.0)
	if _electric_left <= 0.0:
		return
	_electric_left = maxf(_electric_left - delta, 0.0)
	# Ток: урон в секунду растёт с числом других врагов под током рядом (связь между врагами).
	var elements: ElementSettings = Config.data.elements
	var neighbors: int = 0
	for other: Node in get_tree().get_nodes_in_group(&"enemies"):
		var enemy: Enemy = other as Enemy
		if enemy != null and enemy != self and not enemy.is_dead and enemy.is_electrified() \
				and enemy.global_position.distance_to(global_position) <= elements.electric_chain_radius:
			neighbors += 1
	neighbors = mini(neighbors, elements.electric_chain_max_neighbors)
	var tick: float = _electric_dps * (1.0 + elements.electric_chain_bonus * neighbors) * delta * get_damage_taken_multiplier()
	_dot_pending += tick
	_dot_number_left -= delta
	if _dot_number_left <= 0.0 and _dot_pending >= 1.0:
		DamageNumber.spawn(get_parent(), global_position + Vector3(0.0, settings.health_bar_height - 0.5, 0.0), _dot_pending, false, CombatEnums.Element.ELECTRIC)
		_dot_pending = 0.0
		_dot_number_left = DOT_NUMBER_INTERVAL
	_lose_health(tick)


func _lose_health(amount: float) -> void:
	health = maxf(health - amount, 0.0)
	if health <= 0.0 and not is_dead:
		_die()


func _die() -> void:
	is_dead = true
	remove_from_group(&"enemies")
	_blast_on_death()
	if _gives_rewards():
		_drop_loot()
		var xp: int = roundi(float(settings.xp_reward) * (modifier.reward_mult if modifier != null else 1.0))
		Progress.add_xp(xp)
		if xp > 0:
			get_tree().call_group(&"hud", &"show_pickup", tr("HUD_PICKUP_XP").format({"amount": xp}))
	visible = false
	set_deferred("collision_layer", 0)
	set_physics_process(false)
	died.emit(self)
	# Узел живёт ещё немного: цифры урона и проверки успевают к нему обратиться.
	get_tree().create_timer(0.5).timeout.connect(queue_free)


# Особенности префикса (№92): восстановление после паузы без попаданий и ярость при низком здоровье.
func _update_modifier(delta: float) -> void:
	if modifier == null:
		return
	if modifier.regen_per_second > 0.0 and _since_hit >= modifier.regen_delay and health < get_max_health():
		heal(get_max_health() * modifier.regen_per_second * delta)
	if modifier.enrage_below > 0.0:
		var should_enrage: bool = health < get_max_health() * modifier.enrage_below
		if should_enrage != enraged:
			enraged = should_enrage
			damage_scale = _base_damage_scale * (modifier.enrage_damage_mult if enraged else 1.0)


# Взрыв при гибели (префикс «Подрывник»): задевает только игрока в радиусе, сила растёт вместе с уроном врага.
func _blast_on_death() -> void:
	if modifier == null or modifier.death_blast_radius <= 0.0:
		return
	var origin: Vector3 = global_position + Vector3(0.0, 0.6, 0.0)
	BlastEffect.spawn(get_parent(), origin, modifier.death_blast_radius, modifier.tint if modifier.tint_amount > 0.0 else Color(1.0, 0.5, 0.2))
	Blast.apply(self, origin, modifier.death_blast_radius, 0.0, CombatEnums.Element.NONE, 0.5, modifier.death_blast_damage * _base_damage_scale, [get_rid()])


## Даёт ли гибель награду (деньги, опыт, дроп). Камикадзе, взорвавшийся сам, награды не даёт.
func _gives_rewards() -> bool:
	return true


func _drop_loot() -> void:
	var parent: Node = get_parent()
	var at: Vector3 = global_position + Vector3(0.0, 0.8, 0.0)
	var money: int = roundi(float(rng.randi_range(settings.money_min, maxi(settings.money_min, settings.money_max))) * (modifier.reward_mult if modifier != null else 1.0))
	if money > 0:
		Pickup.spawn(parent, at, Pickup.Kind.MONEY, float(money))
	if rng.randf() < settings.medkit_chance:
		Pickup.spawn(parent, at, Pickup.Kind.MEDKIT, settings.medkit_heal)
	# Деталь оружия отдельным предметом: выпадает заметно чаще целого оружия (оно из врагов не падает).
	if settings.part_chance > 0.0 and rng.randf() < settings.part_chance * loot_chance_multiplier():
		var generator: WeaponGenerator = WeaponGenerator.new(Config.data.weapons)
		var rolled: PartInstance = generator.generate_part(rng)
		if rolled != null:
			var loot: LootSettings = Config.data.loot
			var toss: Vector3 = Vector3(rng.randf_range(-1.0, 1.0) * loot.scatter_speed, loot.toss_speed, rng.randf_range(-1.0, 1.0) * loot.scatter_speed)
			ItemPickup.spawn(parent, InventoryItem.from_part(rolled, Config.data.weapons), at, toss)
	# Граната (№92): уровня врага.
	if settings.grenade_chance > 0.0 and rng.randf() < settings.grenade_chance * loot_chance_multiplier():
		var grenades: GrenadeGenerator = GrenadeGenerator.new(Config.data.grenades, Config.data.weapons.quality_scale)
		ItemPickup.spawn_tossed(parent, InventoryItem.from_grenade(grenades.generate(rng, level)), at, rng)
	# Щит игрока (№93): уровня врага.
	if settings.shield_item_chance > 0.0 and rng.randf() < settings.shield_item_chance * loot_chance_multiplier():
		var shields: ShieldGenerator = ShieldGenerator.new(Config.data.shields, Config.data.weapons.quality_scale)
		ItemPickup.spawn_tossed(parent, InventoryItem.from_shield(shields.generate(rng, level)), at, rng)
	# Хлам для продажи (№91).
	if settings.junk_chance > 0.0 and rng.randf() < settings.junk_chance * loot_chance_multiplier():
		var junk: InventoryItem = JunkLoot.roll(rng, Config.data.props)
		if junk != null:
			ItemPickup.spawn_tossed(parent, junk, at, rng)


# Общие помощники для наследников.

## Горизонтальное расстояние и вертикальная разница до игрока.
func _flat_to(player: Player) -> Vector3:
	var to_player: Vector3 = player.global_position - global_position
	return Vector3(to_player.x, 0.0, to_player.z)


## Пускает снаряд из точки from к цели target с разбросом projectile_spread (стрелки).
func _shoot_projectile(from: Vector3, target: Vector3) -> void:
	var direction: Vector3 = (target - from).normalized()
	if settings.projectile_spread > 0.0:
		var spread: float = deg_to_rad(settings.projectile_spread)
		var side: Vector3 = direction.cross(Vector3.UP)
		if side.length() < 0.01:
			side = Vector3.RIGHT
		side = side.normalized()
		var up: Vector3 = direction.cross(side).normalized()
		var angle: float = rng.randf() * TAU
		var offset: float = spread * sqrt(rng.randf())
		direction = (direction + (side * cos(angle) + up * sin(angle)) * tan(offset)).normalized()
	EnemyProjectile.spawn(get_parent(), from, direction * settings.projectile_speed, settings.projectile_damage * damage_scale, settings.projectile_lifetime, settings.projectile_radius)


## Смещение точки подхода в сторону от прямой на игрока (по горизонтали): боковая полоса врага, плавно уходящая в ноль при
## приближении. to_player: вектор от врага к игроку, distance: расстояние до игрока.
func _flank_offset(to_player: Vector3, distance: float) -> Vector3:
	if settings.flank_width <= 0.0 or distance <= settings.flank_close_distance:
		return Vector3.ZERO
	var flat: Vector3 = Vector3(to_player.x, 0.0, to_player.z)
	if flat.length() < 0.01:
		return Vector3.ZERO
	var side: Vector3 = Vector3(-flat.z, 0.0, flat.x).normalized()
	var fade: float = clampf((distance - settings.flank_close_distance) / maxf(settings.flank_fade_distance, 0.1), 0.0, 1.0)
	return side * flank_lane * settings.flank_width * fade


## Поворачивает врага лицом (-Z) в сторону направления.
func _face(direction: Vector3) -> void:
	if Vector2(direction.x, direction.z).length() > 0.001:
		rotation.y = atan2(-direction.x, -direction.z)


## Проверка прямой видимости по миру (стены и башни закрывают).
func _line_of_sight(from: Vector3, to: Vector3) -> bool:
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
