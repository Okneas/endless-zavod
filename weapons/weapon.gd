class_name Weapon
extends Node3D
## Оружие игрока: слоты, магазин, перезарядка, стрельба лучом с разбросом, крит, отдача и прицеливание (ПКМ).
## В слоте лежит WeaponInstance (части с качеством и модификаторами), характеристики считаются из него.
## Слот 1 занимает стартовый пистолет из WeaponDefinition (поле Definition), остальные выдаёт генератор.
## Общие правила стрельбы лежат в ShootingSettings. Модель собирается из частей (WeaponModelBuilder).

signal ammo_changed(current: int, capacity: int)
signal reload_started
signal reload_finished
## Выстрел: на сколько градусов подбросить камеру (отдача).
signal fired(recoil_degrees: float)
## Выстрел для эффектов и проверок: направление луча, конечная точка и было ли попадание.
signal shot_traced(direction: Vector3, end_point: Vector3, hit_something: bool)
signal hit_confirmed(is_crit: bool, killed: bool)
## Сменился активный слот или оружие в нём (после замены, выдачи или смены).
signal slot_changed(slot: int)
## Изменился состав слотов: оружие экипировали, сняли или заменили (для панели слотов на HUD и экрана инвентаря).
signal loadout_changed

## Слои физики: 1 «world», 3 «enemy» (значения битов).
const WORLD_LAYER_MASK: int = 1
const ENEMY_LAYER_MASK: int = 4

@export_group("Настройки")
## Из каких частей собрано стартовое оружие (слот 1). Править в Inspector или двойным щелчком по .tres.
@export var definition: WeaponDefinition
## Общие правила стрельбы: разброс, отдача, эффекты.
@export var shooting: ShootingSettings

## Слоты оружия (пустой слот = null) и номер активного.
var slots: Array[WeaponInstance] = []
var active_slot: int = 0
## Оружие в руках (элемент slots[active_slot]).
var instance: WeaponInstance
var stats: WeaponStats
var ammo: int = 0
var is_reloading: bool = false
## Насколько включено прицеливание: 0 от бедра, 1 полностью.
var aim_amount: float = 0.0
## Контекст движения: игрок выставляет каждый тик, от него зависит разброс.
var motion_speed: float = 0.0
var airborne: bool = false
## Игрок в подкате: нужен особенности аксессуара «урон в подкате».
var sliding: bool = false
## Крит игрока (складывается с критом оружия), выставляет игрок.
var crit_bonus: float = 0.0
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

var _player: CharacterBody3D
var _camera: Camera3D
var _cooldown: float = 0.0
var _reload_left: float = 0.0
var _fire_buffer: float = 0.0
var _bloom: float = 0.0
var _kick: float = 0.0
var _swing: float = 0.0
var _swing_time: float = 0.2
var _effects: Node3D
var _tracer_mesh: BoxMesh
var _tracer_material: StandardMaterial3D
var _marker_mesh: SphereMesh
var _marker_material: StandardMaterial3D
var _markers: Array[MeshInstance3D] = []
# Смена оружия: в какой слот меняем, сколько осталось и была ли уже подмена на середине.
var _swap_to: int = -1
var _swap_left: float = 0.0
var _swap_applied: bool = false
# Собранная из частей модель и исходная ручная модель стартового пистолета (из сцены).
var _generated_model: Node3D
var _default_nodes: Array[Node3D] = []
var _default_muzzle: Vector3 = Vector3.ZERO
var _default_anchor: Vector3 = Vector3.ZERO
# Парное оружие (акимбо): два ствола, данные корпуса, точка дула в системе ствола и чей выстрел следующий.
var _gun_muzzle: Vector3 = Vector3.ZERO
var _first_gun: Node3D
var _second_gun: Node3D
var _dual_body: WeaponPart
var _has_second_muzzle: bool = false
var _second_next: bool = false

@onready var _viewmodel: Node3D = $Viewmodel
@onready var _muzzle: Node3D = $Viewmodel/Muzzle
# Точка прицела на модели: через неё смотрит глаз при прицеливании (прорезь, центр оптики и т.д.).
@onready var _aim_anchor: Node3D = $Viewmodel/AimAnchor


func _ready() -> void:
	assert(definition != null and shooting != null, "У оружия не назначены части (WeaponDefinition) или правила стрельбы (ShootingSettings)")
	var generation: WeaponGenerationSettings = Config.data.weapons
	slots.resize(generation.slot_count)
	# Стартовое оружие: вечный пистолет из фиксированного набора, уровень равен уровню персонажа (04-extraction).
	var starter: WeaponInstance = WeaponInstance.from_definition(definition, Progress.level, generation.starter_quality, generation)
	starter.follows_player_level = true
	starter.is_eternal = true
	slots[0] = starter
	for child: Node in _viewmodel.get_children():
		if child is MeshInstance3D:
			_default_nodes.append(child as Node3D)
	_default_muzzle = _muzzle.position
	_default_anchor = _aim_anchor.position
	Progress.level_changed.connect(_on_level_changed)
	rng.randomize()
	# Эффекты живут в мировых координатах и не едут вместе с камерой.
	_effects = Node3D.new()
	_effects.top_level = true
	add_child(_effects)
	_tracer_mesh = BoxMesh.new()
	_tracer_mesh.size = Vector3.ONE
	_tracer_material = _unshaded(Color(1.0, 0.9, 0.5))
	_marker_mesh = SphereMesh.new()
	_marker_mesh.radius = shooting.marker_size
	_marker_mesh.height = shooting.marker_size * 2.0
	_marker_material = _unshaded(Color(0.1, 0.1, 0.12))
	_activate(0)


func setup(player: CharacterBody3D, camera: Camera3D) -> void:
	_player = player
	_camera = camera
	ammo_changed.emit(ammo, stats.magazine_size)


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_bloom = maxf(_bloom - shooting.bloom_recovery * delta, 0.0)
	_read_slot_input()
	if _swap_to >= 0:
		_update_swap(delta)
		return
	# Нажатие запоминается ненадолго: быстрые клики не теряются, пока оружие «остывает».
	if Input.is_action_just_pressed(&"fire"):
		_fire_buffer = shooting.fire_buffer_time
	else:
		_fire_buffer = maxf(_fire_buffer - delta, 0.0)
	if is_reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()
	elif Input.is_action_just_pressed(&"reload"):
		start_reload()
	var wants_fire: bool = (stats.automatic and Input.is_action_pressed(&"fire")) or _fire_buffer > 0.0
	if wants_fire and _cooldown <= 0.0 and not is_reloading:
		_fire_buffer = 0.0
		if ammo <= 0:
			# Автоперезарядка: нажали огонь при пустом магазине.
			start_reload()
		else:
			_fire()


func _process(delta: float) -> void:
	# Перезарядка прерывает прицеливание; если ПКМ всё ещё зажата, прицеливание вернётся после неё.
	var wants_aim: bool = Input.is_action_pressed(&"aim") and not is_reloading
	aim_amount = move_toward(aim_amount, 1.0 if wants_aim else 0.0, delta / maxf(stats.aim_time, 0.01))
	_kick = move_toward(_kick, 0.0, shooting.viewmodel_recover_speed * delta)
	_swing = move_toward(_swing, 0.0, delta / maxf(_swing_time, 0.01))
	_update_viewmodel()


## Колесо мыши листает оружие по занятым слотам (клавиши 1-4 читаются в _physics_process).
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"weapon_next"):
		switch_to(_neighbor_slot(1))
	elif event.is_action_pressed(&"weapon_prev"):
		switch_to(_neighbor_slot(-1))


## Положить оружие в первый пустой слот, а если все заняты, вместо активного. Возвращает номер слота.
## Если оружие легло не в активный слот, начинается смена на него.
func give_weapon(weapon: WeaponInstance) -> int:
	var slot: int = active_slot
	for i: int in slots.size():
		if slots[i] == null:
			slot = i
			break
	slots[slot] = weapon
	loadout_changed.emit()
	if slot == active_slot:
		_activate(slot)
	else:
		switch_to(slot)
	return slot


## Снимок снаряжения (все слоты) для переноса между сценами: хаб, забег (№88). Активное оружие сохраняет остаток патронов.
func export_loadout() -> Array:
	if instance != null:
		instance.ammo = ammo
	return slots.duplicate()


## Расставить в слотах снаряжение из снимка export_loadout(). Лишние и отсутствующие слоты пропускаются, в руки берётся прежний активный
## слот, а если он пуст, первое оружие.
func import_loadout(list: Array) -> void:
	var occupied: int = 0
	for i: int in slots.size():
		slots[i] = list[i] as WeaponInstance if i < list.size() else null
		if slots[i] != null:
			occupied += 1
	if occupied == 0:
		slots[0] = instance
	var target: int = active_slot if slots[active_slot] != null else 0
	for i: int in slots.size():
		if slots[target] == null and slots[i] != null:
			target = i
	_swap_to = -1
	_activate(target)
	loadout_changed.emit()


## Сколько слотов занято.
func occupied_count() -> int:
	var count: int = 0
	for slot_instance: WeaponInstance in slots:
		if slot_instance != null:
			count += 1
	return count


## Слот для нового оружия: первый пустой, а если все заняты, активный.
func find_equip_slot() -> int:
	for i: int in slots.size():
		if slots[i] == null:
			return i
	return active_slot


## Положить оружие в слот вместо того, что там было. Возвращает вытесненное оружие или null.
## В активном слоте оружие меняется сразу, без анимации смены.
func equip_into(slot: int, weapon: WeaponInstance) -> WeaponInstance:
	var replaced: WeaponInstance = slots[slot]
	_swap_to = -1
	if weapon.follows_player_level:
		weapon.level = Progress.level
	slots[slot] = weapon
	if slot == active_slot:
		_activate(slot)
	elif instance == null:
		_activate(slot)
	loadout_changed.emit()
	return replaced


## Убрать оружие из слота. Возвращает снятое оружие. Последнее оружие снять нельзя (вернётся null).
## Если снят активный слот, в руки берётся первое другое оружие.
func remove_from_slot(slot: int) -> WeaponInstance:
	if slots[slot] == null or occupied_count() <= 1:
		return null
	var removed: WeaponInstance = slots[slot]
	_swap_to = -1
	if slot == active_slot:
		removed.ammo = ammo
		slots[slot] = null
		for i: int in slots.size():
			if slots[i] != null:
				_activate(i)
				break
	else:
		slots[slot] = null
	loadout_changed.emit()
	return removed


## Сменить оружие на слот. Возвращает false, если слот пуст или уже активен.
func switch_to(slot: int) -> bool:
	if slot < 0 or slot >= slots.size() or slots[slot] == null or slot == _swap_to:
		return false
	if slot == active_slot and _swap_to < 0:
		return false
	if shooting.swap_time <= 0.0:
		_activate(slot)
		return true
	_swap_to = slot
	_swap_left = shooting.swap_time
	_swap_applied = false
	# Смена прерывает перезарядку.
	is_reloading = false
	_reload_left = 0.0
	return true


func is_swapping() -> bool:
	return _swap_to >= 0


## Название оружия в руках (по правилам названия, №49).
func get_display_name() -> String:
	return instance.get_display_name()


## Начать перезарядку (R или автоматически). Бесконечные патроны: магазин просто наполняется.
func start_reload() -> void:
	if is_reloading or ammo >= stats.magazine_size:
		return
	is_reloading = true
	_reload_left = stats.reload_time
	reload_started.emit()


## Кратность приближения с учётом того, насколько включено прицеливание.
func get_zoom() -> float:
	return lerpf(1.0, stats.aim_zoom, aim_amount)


func get_reload_progress() -> float:
	if not is_reloading:
		return 0.0
	return clampf(1.0 - _reload_left / maxf(stats.reload_time, 0.01), 0.0, 1.0)


## Текущая половина угла разброса, градусы (№90, кучность как в Borderlands): кучность оружия, движение, воздух, раскрытие при
## стрельбе (в долях кучности), прицеливание. Это максимальный угол конуса: пули чаще ложатся ближе к центру (spread_center_bias).
func get_current_spread() -> float:
	var spread: float = stats.spread_deg
	var speed_ratio: float = clampf(motion_speed / shooting.full_spread_speed, 0.0, 1.0)
	# Приклад гасит добавку разброса от движения (movement_spread_mult меньше 1.0).
	spread *= 1.0 + shooting.movement_spread_factor * speed_ratio * stats.movement_spread_mult
	if airborne:
		spread *= shooting.air_spread_factor
	spread *= 1.0 + _bloom
	var aim_multiplier: float = shooting.aim_spread_multiplier if stats.pellets <= 1 else shooting.pellet_aim_spread_multiplier
	return spread * lerpf(1.0, aim_multiplier, aim_amount)


## Взмах оружия при ударе в ближнем бою (только визуально).
func play_melee_swing(duration: float) -> void:
	_swing_time = duration
	_swing = 1.0


func _finish_reload() -> void:
	is_reloading = false
	ammo = stats.magazine_size
	ammo_changed.emit(ammo, stats.magazine_size)
	reload_finished.emit()


func _fire() -> void:
	ammo -= 1
	_cooldown = 1.0 / maxf(stats.fire_rate, 0.01)
	var spread: float = get_current_spread()
	_bloom = minf(_bloom + shooting.bloom_per_shot, shooting.bloom_max)
	var from: Vector3 = _camera.global_position
	# Парное оружие стреляет по очереди из каждого ствола: трассер начинается у нужного дула.
	if _has_second_muzzle:
		var gun: Node3D = _second_gun if _second_next else _first_gun
		_muzzle.position = gun.position + gun.basis * _gun_muzzle
		_second_next = not _second_next
	var exclude: Array[RID] = [_player.get_rid()]
	var space: PhysicsDirectSpaceState3D = _player.get_world_3d().direct_space_state
	var pellet_count: int = maxi(stats.pellets, 1)
	# Попадания дробин собираются по цели: цель получает один удар со всем уроном дробин и показывает цифру на каждую.
	var hits: Dictionary = {}
	for i: int in pellet_count:
		var direction: Vector3 = _spread_direction(spread)
		var to: Vector3 = from + direction * stats.weapon_range
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from, to, WORLD_LAYER_MASK | ENEMY_LAYER_MASK, exclude)
		var hit: Dictionary = space.intersect_ray(query)
		var end_point: Vector3 = to
		if not hit.is_empty():
			end_point = hit["position"]
			var collider: Object = hit["collider"]
			if collider != null and collider.has_method(&"take_hit"):
				if not hits.has(collider):
					hits[collider] = []
				hits[collider].append(end_point)
			else:
				_spawn_marker(end_point)
		_spawn_tracer(end_point)
		shot_traced.emit(direction, end_point, not hit.is_empty())
	for target: Object in hits:
		_apply_hit(target, hits[target][0], hits[target])
	_kick = 1.0
	fired.emit(stats.recoil_deg)
	ammo_changed.emit(ammo, stats.magazine_size)


# pellet_points: точки попадания дробин в эту цель (урон выстрела делится между всеми дробинами оружия).
# Крит бросается на каждую дробину отдельно. Пустой список: одно попадание в точку point.
func _apply_hit(collider: Object, point: Vector3, pellet_points: Array = []) -> void:
	var points: Array = pellet_points if not pellet_points.is_empty() else [point]
	var crit_chance: float = clampf(crit_bonus + stats.crit_chance, 0.0, 1.0)
	var share: float = stats.damage / float(maxi(stats.pellets, 1))
	# Особенности аксессуара: бонус урона в подкате и в воздухе.
	var situational: float = 1.0
	if sliding:
		situational += stats.slide_damage_bonus
	if airborne:
		situational += stats.air_damage_bonus
	var info: DamageInfo = DamageInfo.create(0.0, false, point)
	for pellet_point: Vector3 in points:
		# Слабое место врага (№93): попадание всегда крит, а множитель берётся у врага вместо обычного множителя крита.
		var weak_multiplier: float = _weak_point_multiplier(collider, pellet_point)
		var is_weak: bool = weak_multiplier > 1.0
		var is_crit: bool = is_weak or rng.randf() < crit_chance
		var amount: float = share * situational * (weak_multiplier if is_weak else (shooting.crit_multiplier if is_crit else 1.0))
		var pellet: PelletHit = PelletHit.create(amount, is_crit, pellet_point)
		pellet.is_weak_point = is_weak
		info.pellets.append(pellet)
		info.amount += amount
		info.is_crit = info.is_crit or is_crit
		info.is_weak_point = info.is_weak_point or is_weak
	info.element = stats.element
	info.weapon_type = stats.weapon_type
	var killed: bool = collider.call(&"take_hit", info)
	hit_confirmed.emit(info.is_crit, killed)


# Множитель слабого места цели в точке попадания (1, если у цели слабого места нет или выстрел мимо него).
func _weak_point_multiplier(collider: Object, point: Vector3) -> float:
	if collider.has_method(&"get_weak_point_multiplier_at"):
		return collider.call(&"get_weak_point_multiplier_at", point)
	return 1.0


# Случайная точка внутри конуса: расстояние от центра равно доле конуса в степени spread_center_bias (0.5 даёт равномерность по
# площади круга, 1.0 и больше смещают пули к центру, №90).
func _spread_direction(spread_deg: float) -> Vector3:
	var basis: Basis = _camera.global_basis
	var angle: float = rng.randf() * TAU
	var radius: float = tan(deg_to_rad(spread_deg)) * pow(rng.randf(), shooting.spread_center_bias)
	return (-basis.z + basis.x * (cos(angle) * radius) + basis.y * (sin(angle) * radius)).normalized()


func _update_viewmodel() -> void:
	# Положение прицеливания: AimAnchor встаёт в центр экрана на расстоянии aim_eye_distance от глаза.
	# Так линия прицела (прорезь, мушка) совпадает с направлением выстрела при любом оружии.
	var anchor: Vector3 = _aim_anchor.position
	if _dual_body != null:
		# Акимбо: в прицеливании стволы сводятся к середине и наклоняются внутрь, к центру экрана приводится середина между ними.
		var aim_offset: Vector3 = _dual_body.second_aim_offset if _dual_body.second_aim_offset != Vector3.ZERO else _dual_body.second_model_offset
		var spacing: Vector3 = _dual_body.second_model_offset.lerp(aim_offset, aim_amount)
		var roll: float = deg_to_rad(_dual_body.dual_aim_tilt_deg) * aim_amount
		_second_gun.position = spacing
		_first_gun.rotation = Vector3(0.0, roll * 0.5, roll)
		_second_gun.rotation = Vector3(0.0, -roll * 0.5, -roll)
		anchor += spacing * 0.5
	var aim_position: Vector3 = Vector3(0.0, 0.0, -shooting.aim_eye_distance) - anchor
	var position_now: Vector3 = shooting.hip_position.lerp(aim_position, aim_amount)
	var kick: float = _kick * lerpf(1.0, shooting.aim_viewmodel_kick_multiplier, aim_amount)
	position_now.z += shooting.viewmodel_kick_back * kick
	# Смена оружия: модель опускается к середине и поднимается обратно.
	if _swap_to >= 0 and shooting.swap_time > 0.0:
		var phase: float = 1.0 - _swap_left / shooting.swap_time
		position_now.y -= shooting.swap_drop * sin(clampf(phase, 0.0, 1.0) * PI)
	# Взмах: кривая 0 -> 1 -> 0 за время удара.
	var swing: float = sin((1.0 - _swing) * PI) if _swing > 0.0 else 0.0
	position_now += Vector3(-0.12, -0.05, -0.1) * swing
	_viewmodel.position = position_now
	_viewmodel.rotation = Vector3(deg_to_rad(shooting.viewmodel_kick_up) * kick - deg_to_rad(40.0) * swing, deg_to_rad(25.0) * swing, 0.0)


func _unshaded(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	return material


func _spawn_tracer(end_point: Vector3) -> void:
	var from: Vector3 = _muzzle.global_position
	var length: float = from.distance_to(end_point)
	if length < 0.05:
		return
	var tracer: MeshInstance3D = MeshInstance3D.new()
	tracer.mesh = _tracer_mesh
	tracer.material_override = _tracer_material
	_effects.add_child(tracer)
	var direction: Vector3 = (end_point - from) / length
	# Строго вверх или вниз Basis.looking_at ломается: берём другую «верхнюю» ось.
	var up: Vector3 = Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT
	tracer.global_transform = Transform3D(Basis.looking_at(direction, up), from.lerp(end_point, 0.5))
	tracer.scale = Vector3(shooting.tracer_thickness, shooting.tracer_thickness, length)
	get_tree().create_timer(shooting.tracer_time).timeout.connect(func() -> void:
		if is_instance_valid(tracer):
			tracer.queue_free())


# Метка попадания в стену: по ним хорошо видно разброс. Старые метки удаляются сверх лимита.
func _spawn_marker(point: Vector3) -> void:
	if shooting.marker_limit <= 0:
		return
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.mesh = _marker_mesh
	marker.material_override = _marker_material
	_effects.add_child(marker)
	marker.global_position = point
	_markers.append(marker)
	while _markers.size() > shooting.marker_limit:
		var oldest: MeshInstance3D = _markers.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	get_tree().create_timer(shooting.marker_lifetime).timeout.connect(func() -> void:
		if is_instance_valid(marker):
			_markers.erase(marker)
			marker.queue_free())

func _read_slot_input() -> void:
	for i: int in slots.size():
		var action: StringName = StringName("weapon_slot_%d" % (i + 1))
		if InputMap.has_action(action) and Input.is_action_just_pressed(action):
			switch_to(i)


# Ближайший занятый слот в сторону direction (1 вперёд, -1 назад) по кругу. Нет другого оружия: -1.
func _neighbor_slot(direction: int) -> int:
	var origin: int = _swap_to if _swap_to >= 0 else active_slot
	for step: int in range(1, slots.size()):
		var index: int = posmod(origin + direction * step, slots.size())
		if slots[index] != null:
			return index
	return -1


func _update_swap(delta: float) -> void:
	_swap_left -= delta
	# Оружие подменяется на середине смены, пока модель опущена.
	if not _swap_applied and _swap_left <= shooting.swap_time * 0.5:
		_swap_applied = true
		_activate(_swap_to)
	if _swap_left <= 0.0:
		_swap_to = -1


# Берёт оружие из слота в руки: считает характеристики, достаёт патроны, собирает модель.
func _activate(slot: int) -> void:
	if instance != null:
		instance.ammo = ammo
	active_slot = slot
	instance = slots[slot]
	stats = instance.compute_stats()
	ammo = stats.magazine_size if instance.ammo < 0 else mini(instance.ammo, stats.magazine_size)
	is_reloading = false
	_reload_left = 0.0
	_cooldown = 0.0
	_bloom = 0.0
	_fire_buffer = 0.0
	_rebuild_model()
	ammo_changed.emit(ammo, stats.magazine_size)
	slot_changed.emit(slot)


# Модель из частей. Если у корпуса нет данных модели (стартовый пистолет), остаётся ручная модель из сцены.
func _rebuild_model() -> void:
	if _generated_model != null:
		_viewmodel.remove_child(_generated_model)
		_generated_model.queue_free()
		_generated_model = null
	var has_model: bool = instance.get_body().part.model_size != Vector3.ZERO
	for node: Node3D in _default_nodes:
		node.visible = not has_model
	if has_model:
		var built: WeaponModelBuilder.Result = WeaponModelBuilder.build(instance)
		_viewmodel.add_child(built.root)
		_generated_model = built.root
		_gun_muzzle = built.muzzle
		_has_second_muzzle = built.has_second
		_first_gun = built.root.get_node_or_null("First") as Node3D
		_second_gun = built.root.get_node_or_null("Second") as Node3D
		_dual_body = instance.get_body().part if built.has_second else null
		_aim_anchor.position = built.aim_anchor
	else:
		_gun_muzzle = _default_muzzle
		_has_second_muzzle = false
		_first_gun = null
		_second_gun = null
		_dual_body = null
		_aim_anchor.position = _default_anchor
	_second_next = false
	_muzzle.position = _gun_muzzle


# Стартовое оружие растёт вместе с персонажем: меняется только урон, магазин и патроны остаются.
func _on_level_changed(level: int) -> void:
	for slot_instance: WeaponInstance in slots:
		if slot_instance != null and slot_instance.follows_player_level:
			slot_instance.level = level
	if instance != null and instance.follows_player_level and stats != null:
		stats.damage = instance.compute_stats().damage
