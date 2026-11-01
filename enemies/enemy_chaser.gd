class_name EnemyChaser
extends Enemy
## Преследующий (№38): идёт к игроку по земле и бьёт в ближнем бою. Если в зоне есть сетка навигации
## (её запекает генератор зоны, срез 6), огибает препятствия по ней, иначе идёт прямо (тестовая комната).
## Прыжок на игрока (срез 7б, №83, как психи из Borderlands): на средней дистанции при прямой видимости враг замирает
## (замах с подсветкой), прыгает в точку, где стоял игрок, и бьёт при попадании или приземлении рядом. Включается полем
## leap_cooldown в настройках (0 — враг не прыгает).

## Как часто пересчитывается путь к игроку, с.
const REPATH_INTERVAL: float = 0.3
## Запечённая сетка лежит над полом примерно на радиус агента, на пандусах чуть выше: без поправки путевая точка над
## ногами врага не считалась бы достигнутой, и он топтался бы у начала пандуса. Смещение вычитается из высоты точек пути.
const NAV_HEIGHT_OFFSET: float = 0.5
const NAV_REACHED_DISTANCE: float = 1.0
## Сетка навигации разрешает ступеньки до 0.45 м (nav_agent_max_climb), а тело без прыжка берёт только около 0.1 м. Если враг
## дольше STUCK_TIME идёт вперёд, но почти не движется, упёршись в неподвижную геометрию, он подпрыгивает на HOP_SPEED.
## Упор в другого врага или игрока не считается (иначе толпа прыгала бы на месте).
const STUCK_TIME: float = 0.35
const STUCK_SPEED_RATIO: float = 0.3
const HOP_SPEED: float = 6.0
## Прыжок на игрока: разница высот, с которой он ещё возможен, и запас времени полёта сверх расчётного.
const LEAP_MAX_HEIGHT_DIFFERENCE: float = 2.5
const LEAP_AIR_SLACK: float = 0.6
## Точка охвата на сетке навигации не должна лежать выше или ниже игрока больше чем на столько (другой ярус): тогда враг идёт прямо.
const FLANK_MAX_HEIGHT_DIFFERENCE: float = 2.5

enum LeapPhase { NONE, WINDUP, AIR }

var _cooldown: float = 0.0
var _in_range: bool = false
var _agent: NavigationAgent3D
var _repath_left: float = 0.0
## Скорость умножается на этот множитель (босс во второй фазе быстрее). Движение можно запереть (замах босса перед волной).
var speed_multiplier: float = 1.0
var movement_locked: bool = false

var _stuck_time: float = 0.0
var _hop_pending: bool = false

var _leap_phase: LeapPhase = LeapPhase.NONE
var _leap_cooldown_left: float = 0.0
var _leap_phase_left: float = 0.0
var _leap_hit_done: bool = false
var _leap_air_velocity: Vector3 = Vector3.ZERO


func _ready() -> void:
	super._ready()
	# Первый прыжок не у всех одновременно: стартовая пауза случайная.
	_leap_cooldown_left = rng.randf() * settings.leap_cooldown


func _behavior(delta: float, player: Player) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	_leap_cooldown_left = maxf(_leap_cooldown_left - delta, 0.0)
	if _leap_phase != LeapPhase.NONE:
		_leap_step(delta, player)
		return
	var velocity_flat: Vector3 = Vector3.ZERO
	if player != null:
		var flat: Vector3 = _flat_to(player)
		var distance: float = flat.length()
		if distance <= settings.aggro_range or always_aggro:
			_face(flat)
			if _can_leap(player, distance):
				_start_leap()
				_move_ground(Vector3.ZERO, delta)
				return
			if distance > settings.melee_range * 0.9:
				velocity_flat = _walk_direction(player, flat, distance, delta) * settings.move_speed * get_speed_multiplier() * speed_multiplier
			var close: bool = distance <= settings.melee_range and absf(player.global_position.y - global_position.y) < 1.6
			if close and not _in_range:
				# Только что подошёл: первый удар не сразу, игроку остаётся миг на реакцию.
				_cooldown = maxf(_cooldown, settings.melee_cooldown * 0.5)
			_in_range = close
			if close and _cooldown <= 0.0:
				_cooldown = settings.melee_cooldown
				player.take_damage(settings.melee_damage * damage_scale, global_position)
		else:
			_in_range = false
	else:
		_in_range = false
	if movement_locked:
		velocity_flat = Vector3.ZERO
	_move_ground(velocity_flat, delta)


## Движение по земле с тяжестью, подпрыгиванием при упоре и учётом застревания. Общее для преследующего и стрелка.
func _move_ground(velocity_flat: Vector3, delta: float) -> void:
	velocity.x = velocity_flat.x
	velocity.z = velocity_flat.z
	if _hop_pending:
		velocity.y = HOP_SPEED
		_hop_pending = false
	else:
		velocity.y = 0.0 if is_on_floor() else velocity.y - settings.gravity * delta
	var before: Vector3 = global_position
	move_and_slide()
	_track_stuck(before, velocity_flat, delta)


# Упёрся в неподвижную геометрию, пока шёл: накапливает время, по истечении просит прыжок на следующем тике.
func _track_stuck(before: Vector3, wanted: Vector3, delta: float) -> void:
	if not is_on_floor() or wanted.length() < 0.5:
		_stuck_time = 0.0
		return
	var moved: float = Vector2(global_position.x - before.x, global_position.z - before.z).length() / delta
	if moved >= wanted.length() * STUCK_SPEED_RATIO or not _blocked_by_world():
		_stuck_time = 0.0
		return
	_stuck_time += delta
	if _stuck_time >= STUCK_TIME:
		_hop_pending = true
		_stuck_time = 0.0


# Среди столкновений последнего шага есть неподвижное тело (стена, ступенька), а не другой враг или игрок.
func _blocked_by_world() -> bool:
	for i: int in get_slide_collision_count():
		var collider: Object = get_slide_collision(i).get_collider()
		if collider != null and not (collider is CharacterBody3D):
			return true
	return false


# Горизонтальное направление шага: по пути навигации, если сетка есть и игрок не вплотную, иначе прямо к игроку.
func _walk_direction(player: Player, flat: Vector3, distance: float, delta: float) -> Vector3:
	# Охват (№86): пока далеко, враг идёт не в игрока, а в точку сбоку от него (у каждого своя сторона), ближе сходится к игроку.
	var offset: Vector3 = _flank_offset(flat, distance)
	var aim: Vector3 = player.global_position + offset
	var to_aim: Vector3 = aim - global_position
	to_aim.y = 0.0
	var direct: Vector3 = to_aim.normalized() if to_aim.length() > 0.01 else flat / distance
	if distance < settings.melee_range * 2.0 or NavigationServer3D.map_get_regions(get_world_3d().navigation_map).is_empty():
		return direct
	if _agent == null:
		_agent = NavigationAgent3D.new()
		_agent.path_desired_distance = NAV_REACHED_DISTANCE
		_agent.target_desired_distance = NAV_REACHED_DISTANCE
		_agent.path_height_offset = NAV_HEIGHT_OFFSET
		add_child(_agent)
	_repath_left -= delta
	if _repath_left <= 0.0:
		_agent.target_position = _flank_target(player, aim)
		_repath_left = REPATH_INTERVAL
	if _agent.is_navigation_finished():
		return direct
	var to_next: Vector3 = _agent.get_next_path_position() - global_position
	to_next.y = 0.0
	if to_next.length() < 0.05:
		return direct
	return to_next.normalized()


# Точка на сетке навигации для охвата: ближайшая к желаемой точке сбоку от игрока. Если она ушла на другой уровень или далеко
# (за стену), идём прямо к игроку.
func _flank_target(player: Player, aim: Vector3) -> Vector3:
	if aim.is_equal_approx(player.global_position):
		return player.global_position
	var snapped: Vector3 = NavigationServer3D.map_get_closest_point(get_world_3d().navigation_map, aim)
	if absf(snapped.y - player.global_position.y) > FLANK_MAX_HEIGHT_DIFFERENCE or Vector2(snapped.x - aim.x, snapped.z - aim.z).length() > settings.flank_width * 0.5:
		return player.global_position
	return snapped


# --- Прыжок на игрока

func _can_leap(player: Player, distance: float) -> bool:
	if settings.leap_cooldown <= 0.0 or _leap_cooldown_left > 0.0 or movement_locked or not is_on_floor():
		return false
	if distance < settings.leap_min_range or distance > settings.leap_max_range:
		return false
	if absf(player.global_position.y - global_position.y) > LEAP_MAX_HEIGHT_DIFFERENCE:
		return false
	return _line_of_sight(global_position + Vector3(0.0, 1.0, 0.0), player.get_center_position())


func _start_leap() -> void:
	_leap_phase = LeapPhase.WINDUP
	_leap_phase_left = settings.leap_windup
	telegraph_amount = 1.0


func _leap_step(delta: float, player: Player) -> void:
	match _leap_phase:
		LeapPhase.WINDUP:
			_leap_phase_left -= delta
			if player != null:
				_face(_flat_to(player))
			_move_ground(Vector3.ZERO, delta)
			if _leap_phase_left <= 0.0:
				_launch_leap(player)
		LeapPhase.AIR:
			_leap_phase_left -= delta
			velocity.x = _leap_air_velocity.x
			velocity.z = _leap_air_velocity.z
			velocity.y -= settings.gravity * delta
			move_and_slide()
			if player != null and not _leap_hit_done and player.get_center_position().distance_to(global_position + Vector3(0.0, 0.9, 0.0)) <= settings.leap_hit_radius:
				_leap_hit(player)
			# Приземлился (не в первый миг после толчка) или полёт затянулся: прыжок окончен.
			var landed: bool = is_on_floor() and _leap_phase_left < settings.leap_air_time - 0.15
			if landed or _leap_phase_left < -LEAP_AIR_SLACK:
				if landed and player != null and not _leap_hit_done and _flat_to(player).length() <= settings.leap_hit_radius and absf(player.global_position.y - global_position.y) < 1.6:
					_leap_hit(player)
				_end_leap()


func _launch_leap(player: Player) -> void:
	telegraph_amount = 0.0
	if player == null:
		_end_leap()
		return
	var air_time: float = maxf(settings.leap_air_time, 0.1)
	var to_target: Vector3 = player.global_position - global_position
	# Горизонтальная скорость такая, чтобы за air_time долететь до точки; вертикальная считается из тяжести: приземление ровно в точке.
	_leap_air_velocity = Vector3(to_target.x, 0.0, to_target.z) / air_time
	velocity.y = 0.5 * settings.gravity * air_time + to_target.y / air_time
	_leap_phase = LeapPhase.AIR
	_leap_phase_left = air_time
	_leap_hit_done = false


func _leap_hit(player: Player) -> void:
	_leap_hit_done = true
	player.take_damage(settings.melee_damage * settings.leap_damage_multiplier * damage_scale, global_position)


func _end_leap() -> void:
	_leap_phase = LeapPhase.NONE
	_leap_cooldown_left = settings.leap_cooldown
	telegraph_amount = 0.0
	_cooldown = maxf(_cooldown, settings.melee_cooldown * 0.5)
	_stuck_time = 0.0
