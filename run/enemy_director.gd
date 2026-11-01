class_name EnemyDirector
extends Node
## Появление врагов в комнате и присмотр за ними (№81, №82). Общий код боевых комнат, волн шлюза и эвакуации, элитного
## врага и босса. Враг встаёт только на свободное место на земле (не в блок, не над пропастью, с путём по навигации к игроку),
## а пока он жив, сторож раз в watchdog_interval переносит провалившегося под зону или застрявшего в стене врага на свободное
## место: иначе комната осталась бы закрытой навсегда. Здоровье и урон врагов растут с уровнем зоны (RunSettings).

## Погиб очередной враг (или пропал из дерева: тогда он тоже больше не нужен для конца боя).
signal enemy_died(enemy: Enemy)
## Погиб последний из живых врагов.
signal cleared

## Радиус шара, которым сторож проверяет, что враг не внутри геометрии, и высота его центра над ногами. Шар заметно
## меньше тела, чтобы враг, стоящий вплотную к стене или полу, не считался застрявшим.
const BURIED_PROBE_RADIUS: float = 0.3
const BURIED_PROBE_HEIGHT: float = 0.9
## Сколько проверок подряд враг должен быть внутри геометрии, чтобы его перенесли.
const BURIED_CHECKS: int = 3
## Земля под ногами при появлении: на таком расстоянии вниз должен быть пол.
const GROUND_PROBE_DISTANCE: float = 1.0
## Проверка пути от места появления до игрока: место должно лежать у сетки навигации (по горизонтали и вертикали, м),
## путь должен кончаться не дальше этого от точки игрока (м).
const REACH_SNAP_DISTANCE: float = 1.5
const REACH_SNAP_HEIGHT: float = 1.5
const REACH_END_DISTANCE: float = 1.5

var room: RoomPiece
## Живые враги, которых породил директор.
var enemies: Array[Enemy] = []
var enemies_alive: int = 0
## Сколько раз сторож переносил врагов (провалился, застрял): для проверки и отладки.
var relocations: int = 0

## Враги, которые ждут появления: {enemy, beacon, left}. Пока ждут, они скрыты, а на месте появления светится SpawnBeacon.
var _warnings: Array[Dictionary] = []

var _settings: ZoneSettings
var _zone_number: int = 1
var _zone_level: int = 1
var _fall_limit: float = -INF
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _watch_left: float = 0.0
var _buried: Dictionary = {}


func setup(p_room: RoomPiece, settings: ZoneSettings, zone_number: int, zone_level: int, seed_value: int, fall_limit: float = -INF) -> void:
	room = p_room
	_settings = settings
	_zone_number = zone_number
	_zone_level = zone_level
	_fall_limit = fall_limit
	_rng.seed = seed_value
	name = "EnemyDirector"
	set_physics_process(false)
	room.add_child(self)


## Врагов из пула зоны (по весам, с учётом самой ранней зоны): count штук на маркерах enemy_spawn. Возвращает, сколько встало.
func spawn_pool(count: int) -> int:
	var markers: Array[Marker3D] = _shuffled(room.get_markers(&"enemy_spawn"))
	var placed: int = 0
	var taken: Array[Vector3] = _taken()
	for i: int in count:
		var entry: EnemyPoolEntry = _pick_entry()
		if entry == null or markers.is_empty():
			break
		if _spawn_one(entry.scene, markers, i, taken) != null:
			placed += 1
	return placed


## count врагов заданной сцены на маркерах группы (если такой группы в комнате нет, на enemy_spawn). force: если свободного
## места не нашлось, поставить врага прямо в маркер (элитный враг и босс не должны пропадать: от них зависит выход).
func spawn_scene(scene: PackedScene, count: int, group: StringName = &"enemy_spawn", force: bool = false) -> Array[Enemy]:
	var markers: Array[Marker3D] = room.get_markers(group)
	if markers.is_empty():
		markers = room.get_markers(&"enemy_spawn")
	markers = _shuffled(markers)
	var result: Array[Enemy] = []
	var taken: Array[Vector3] = _taken()
	if markers.is_empty():
		return result
	for i: int in count:
		var enemy: Enemy = _spawn_one(scene, markers, i, taken, force)
		if enemy != null:
			result.append(enemy)
	return result


## count врагов заданной сцены на свободных местах вокруг точки (призыв босса).
func spawn_around(scene: PackedScene, count: int, center: Vector3, radius: float) -> Array[Enemy]:
	var result: Array[Enemy] = []
	var taken: Array[Vector3] = _taken()
	for i: int in count:
		var enemy: Enemy = _make_enemy(scene)
		var placed: bool = false
		for attempt: int in _settings.spawn_attempts:
			var angle: float = _rng.randf() * TAU
			var distance: float = radius * (0.5 + 0.5 * _rng.randf())
			var spot: Vector3 = center + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
			if _is_free(enemy, spot + _air_offset(enemy), _is_flying(enemy), taken):
				enemy.global_position = spot + _air_offset(enemy)
				placed = true
				break
		if placed:
			_register(enemy)
			taken.append(enemy.global_position)
			result.append(enemy)
		else:
			room.remove_child(enemy)
			enemy.free()
	return result


## Убить всех живых (конец боя с боссом: приспешники не остаются бродить по комнате).
func kill_all() -> void:
	for enemy: Enemy in enemies.duplicate():
		if is_instance_valid(enemy) and not enemy.is_dead:
			enemy.take_hit(DamageInfo.create(1.0e9, false, enemy.global_position + Vector3(0.0, 1.0, 0.0)))


func _physics_process(delta: float) -> void:
	_update_warnings(delta)
	_watch_left -= delta
	if _watch_left > 0.0:
		return
	_watch_left = _settings.watchdog_interval
	for enemy: Enemy in enemies.duplicate():
		if not is_instance_valid(enemy) or enemy.is_dead or enemy.dormant:
			continue
		if enemy.global_position.y < _fall_limit:
			_relocate(enemy)
		elif _is_buried(enemy):
			_buried[enemy] = int(_buried.get(enemy, 0)) + 1
			if int(_buried[enemy]) >= BURIED_CHECKS:
				_relocate(enemy)
		else:
			_buried.erase(enemy)


func _spawn_one(scene: PackedScene, markers: Array[Marker3D], index: int, taken: Array[Vector3], force: bool = false) -> Enemy:
	var enemy: Enemy = _make_enemy(scene)
	if not _place(enemy, markers, index, taken):
		if force:
			enemy.global_position = markers[index % markers.size()].global_position
		else:
			# Свободного места не нашлось: враг пропускается, бой не должен зависеть от него.
			room.remove_child(enemy)
			enemy.free()
			return null
	taken.append(enemy.global_position)
	_register(enemy)
	return enemy


func _make_enemy(scene: PackedScene) -> Enemy:
	var enemy: Enemy = scene.instantiate() as Enemy
	var run_settings: RunSettings = Config.data.run
	enemy.level = _zone_level
	enemy.health_scale = ZoneMath.enemy_health_scale(run_settings, _zone_level)
	enemy.damage_scale = ZoneMath.enemy_damage_scale(run_settings, _zone_level)
	# Префикс (№92): один, шанс растёт с зоной; у элитных и боссов его нет.
	if enemy.settings.allows_modifier:
		var prefix: EnemyModifier = Config.data.enemy_modifiers.roll(_rng, _zone_number)
		if prefix != null:
			enemy.apply_modifier(prefix)
	enemy.always_aggro = _settings.combat_alert_all
	room.add_child(enemy)
	return enemy


func _register(enemy: Enemy) -> void:
	enemy.died.connect(_on_enemy_gone)
	enemy.tree_exiting.connect(_on_enemy_gone.bind(enemy))
	enemies.append(enemy)
	enemies_alive += 1
	_watch_left = _settings.watchdog_interval
	set_physics_process(true)
	_begin_warning(enemy)


# Враг погиб или пропал из дерева (его освободили извне): в обоих случаях он больше не нужен для конца боя. Считается один раз.
func _on_enemy_gone(enemy: Enemy) -> void:
	if not enemies.has(enemy):
		return
	enemies.erase(enemy)
	_buried.erase(enemy)
	_drop_warning(enemy)
	enemies_alive -= 1
	enemy_died.emit(enemy)
	if enemies_alive <= 0:
		set_physics_process(false)
		cleared.emit()


# Враг стоит на месте, но скрыт: на полу под ним светится метка, через spawn_warning_time он появляется.
func _begin_warning(enemy: Enemy) -> void:
	var time: float = Config.data.run.spawn_warning_time
	if time <= 0.0:
		return
	enemy.set_dormant(true)
	var at: Vector3 = enemy.global_position
	var ground: Vector3 = at
	var hit: Dictionary = room.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3(0.0, 0.3, 0.0), at + Vector3(0.0, -GROUND_PROBE_DISTANCE * 8.0, 0.0), 1))
	if not hit.is_empty():
		ground = hit["position"]
	var beacon: SpawnBeacon = SpawnBeacon.spawn(room, ground, at.y - ground.y + 1.0, time)
	_warnings.append({"enemy": enemy, "beacon": beacon, "left": time})


func _update_warnings(delta: float) -> void:
	for entry: Dictionary in _warnings.duplicate():
		var enemy: Enemy = entry["enemy"] as Enemy
		entry["left"] = float(entry["left"]) - delta
		if enemy == null or not is_instance_valid(enemy) or enemy.is_dead:
			_remove_warning(entry, false)
		elif float(entry["left"]) <= 0.0:
			enemy.set_dormant(false)
			_remove_warning(entry, true)


func _drop_warning(enemy: Enemy) -> void:
	for entry: Dictionary in _warnings.duplicate():
		if entry["enemy"] == enemy:
			_remove_warning(entry, false)


func _remove_warning(entry: Dictionary, flash: bool) -> void:
	_warnings.erase(entry)
	var beacon: SpawnBeacon = entry["beacon"] as SpawnBeacon
	if beacon == null or not is_instance_valid(beacon):
		return
	if flash:
		beacon.burst()
	else:
		beacon.queue_free()


func _taken() -> Array[Vector3]:
	var result: Array[Vector3] = []
	for other: Enemy in enemies:
		if is_instance_valid(other) and not other.is_dead:
			result.append(other.global_position)
	return result


# Ставит врага на свободное место возле одного из маркеров: сначала в самом маркере, потом со всё большим разбросом и
# переходом к следующим маркерам. Успех, если место нашлось.
func _place(enemy: Enemy, markers: Array[Marker3D], index: int, taken: Array[Vector3]) -> bool:
	var flying: bool = _is_flying(enemy)
	for attempt: int in _settings.spawn_attempts:
		var marker: Marker3D = markers[(index + attempt / 3) % markers.size()]
		var spot: Vector3 = marker.global_position
		if attempt > 0 and _settings.spawn_scatter > 0.0:
			var angle: float = _rng.randf() * TAU
			var radius: float = _settings.spawn_scatter * sqrt(_rng.randf())
			spot += Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		spot += _air_offset(enemy)
		if _is_free(enemy, spot, flying, taken):
			enemy.global_position = spot
			return true
	return false


func _is_flying(enemy: Enemy) -> bool:
	return enemy.is_flier()


# Летающие появляются выше земли.
func _air_offset(enemy: Enemy) -> Vector3:
	return Vector3(0.0, _settings.flyer_spawn_height, 0.0) if _is_flying(enemy) else Vector3.ZERO


# Место свободно, если тело врага там ни во что не упирается, на земле под ногами пол (летающим не нужен), от места есть
# путь по сетке навигации к игроку (наземному) и рядом нет только что поставленных врагов.
func _is_free(enemy: Enemy, spot: Vector3, flying: bool, taken: Array[Vector3]) -> bool:
	var at: Transform3D = Transform3D(enemy.global_transform.basis, spot)
	if enemy.test_move(at, Vector3.ZERO, null, 0.001, true):
		return false
	if not flying and (not enemy.test_move(at, Vector3.DOWN * GROUND_PROBE_DISTANCE) or not _can_reach_player(enemy, spot)):
		return false
	for other: Vector3 in taken:
		if other.distance_to(spot) < _settings.spawn_spacing:
			return false
	return true


# Наземный враг в месте без пути к игроку (отрезанная плита, остров сетки) не смог бы подойти, и бой зависел бы от того,
# найдёт ли игрок его сам. Если сетки навигации или игрока нет, проверка пропускается.
func _can_reach_player(enemy: Enemy, spot: Vector3) -> bool:
	var map: RID = enemy.get_world_3d().navigation_map
	var player: Node3D = get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null or NavigationServer3D.map_get_regions(map).is_empty():
		return true
	var from: Vector3 = NavigationServer3D.map_get_closest_point(map, spot)
	var to: Vector3 = NavigationServer3D.map_get_closest_point(map, player.global_position)
	if Vector2(from.x - spot.x, from.z - spot.z).length() > REACH_SNAP_DISTANCE or absf(from.y - spot.y) > REACH_SNAP_HEIGHT:
		return false
	var path: PackedVector3Array = NavigationServer3D.map_get_path(map, from, to, true)
	return path.size() >= 2 and path[path.size() - 1].distance_to(to) <= REACH_END_DISTANCE


func _is_buried(enemy: Enemy) -> bool:
	var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
	var probe: SphereShape3D = SphereShape3D.new()
	probe.radius = BURIED_PROBE_RADIUS
	query.shape = probe
	query.transform = Transform3D(Basis.IDENTITY, enemy.global_position + Vector3(0.0, BURIED_PROBE_HEIGHT, 0.0))
	query.collision_mask = 1
	return not enemy.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


# Переносит провалившегося или застрявшего врага на свободное место в комнате.
func _relocate(enemy: Enemy) -> void:
	var markers: Array[Marker3D] = _shuffled(room.get_markers(&"enemy_spawn"))
	var taken: Array[Vector3] = []
	for other: Enemy in enemies:
		if other != enemy and is_instance_valid(other) and not other.is_dead:
			taken.append(other.global_position)
	_buried.erase(enemy)
	if markers.is_empty() or not _place(enemy, markers, _rng.randi_range(0, markers.size() - 1), taken):
		return
	enemy.velocity = Vector3.ZERO
	relocations += 1


func _shuffled(markers: Array[Marker3D]) -> Array[Marker3D]:
	# Своя перестановка с сидом комнаты: Array.shuffle() от сида не зависит.
	var result: Array[Marker3D] = markers.duplicate()
	for i: int in range(result.size() - 1, 0, -1):
		var j: int = _rng.randi_range(0, i)
		var swap: Marker3D = result[i]
		result[i] = result[j]
		result[j] = swap
	return result


func _pick_entry() -> EnemyPoolEntry:
	var total: float = 0.0
	for entry: EnemyPoolEntry in _settings.enemy_pool:
		if entry.scene != null and entry.min_zone <= _zone_number:
			total += entry.weight
	if total <= 0.0:
		return null
	var roll: float = _rng.randf() * total
	for entry: EnemyPoolEntry in _settings.enemy_pool:
		if entry.scene != null and entry.min_zone <= _zone_number:
			roll -= entry.weight
			if roll <= 0.0:
				return entry
	return null
