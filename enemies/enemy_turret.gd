class_name EnemyTurret
extends Enemy
## Стационарная турель (№38): не двигается. Замечает игрока двумя способами: на большой дальности
## в пределах угла обзора и в ближнем радиусе со всех сторон (оба требуют прямой видимости).
## Заметив, поворачивается, целится и стреляет очередями медленных снарядов, от которых можно
## увернуться (решение автора). После потери игрока из виду помнит его ещё немного.

var _aim_left: float = -1.0
# Следит ли турель за игроком: видит его сейчас или ещё помнит (lose_sight_time).
var _tracking: bool = false
var _memory_left: float = 0.0
# До начала следующей очереди, пуль осталось в текущей очереди и пауза до следующей пули.
var _burst_cooldown: float = 0.0
var _burst_shots_left: int = 0
var _burst_gap_left: float = 0.0
# Направление, в которое турель смотрит на старте: от него отсчитывается угол обзора.
var _rest_forward: Vector3 = Vector3.FORWARD

@onready var _head: Node3D = $Head
@onready var _muzzle: Node3D = $Head/Muzzle


func _ready() -> void:
	super._ready()
	_rest_forward = -global_basis.z
	_rest_forward.y = 0.0
	_rest_forward = _rest_forward.normalized()


func _behavior(delta: float, player: Player) -> void:
	_burst_cooldown = maxf(_burst_cooldown - delta, 0.0)
	_memory_left = maxf(_memory_left - delta, 0.0)
	var sees: bool = player != null and _sees(player)
	if sees:
		_memory_left = settings.lose_sight_time
	_tracking = player != null and (sees or _memory_left > 0.0)
	if not _tracking:
		_aim_left = -1.0
		_burst_shots_left = 0
		return
	var target: Vector3 = player.get_center_position()
	_turn_head_toward(target, delta)
	if _aim_left < 0.0:
		_aim_left = settings.aim_time
	# Не уходит ниже нуля: отрицательное значение значит «ещё не начинала целиться».
	_aim_left = maxf(_aim_left - delta, 0.0)
	if _burst_shots_left > 0:
		_burst_gap_left -= delta
		if _burst_gap_left <= 0.0:
			_fire_shot(target)
			_burst_shots_left -= 1
			_burst_gap_left = settings.burst_shot_interval
	elif _aim_left <= 0.0 and _burst_cooldown <= 0.0:
		var extra_shots: int = maxi(settings.burst_count - 1, 0)
		_burst_cooldown = maxf(settings.shoot_interval, float(extra_shots) * settings.burst_shot_interval)
		_burst_shots_left = extra_shots
		_burst_gap_left = settings.burst_shot_interval
		_fire_shot(target)


## Турель следит за игроком: видит его или ещё помнит после потери из виду.
func is_tracking() -> bool:
	return _tracking


func _fire_shot(target: Vector3) -> void:
	var direction: Vector3 = (target - _muzzle.global_position).normalized()
	EnemyProjectile.spawn(get_parent(), _muzzle.global_position, direction * settings.projectile_speed, settings.projectile_damage * damage_scale, settings.projectile_lifetime)


## Игрок виден: прямая видимость и либо ближний радиус, либо дальность с углом обзора.
func _sees(player: Player) -> bool:
	var target: Vector3 = player.get_center_position()
	var from: Vector3 = _muzzle.global_position
	var distance: float = from.distance_to(target)
	var close: bool = settings.awareness_radius > 0.0 and distance <= settings.awareness_radius
	if not close:
		if distance > settings.shoot_range:
			return false
		var flat: Vector3 = Vector3(target.x - from.x, 0.0, target.z - from.z)
		if flat.length() > 0.01 and rad_to_deg(_rest_forward.angle_to(flat.normalized())) > settings.view_angle * 0.5:
			return false
	return _line_of_sight(from, target)


# Плавный поворот головы к цели с ограниченной скоростью (градусы в секунду).
func _turn_head_toward(target: Vector3, delta: float) -> void:
	var direction: Vector3 = (target - _head.global_position).normalized()
	var current: Quaternion = _head.global_basis.get_rotation_quaternion()
	var desired: Quaternion = Basis.looking_at(direction, Vector3.UP).get_rotation_quaternion()
	var angle: float = current.angle_to(desired)
	if angle < 0.0001:
		return
	var step: float = minf(1.0, deg_to_rad(settings.turn_speed) * delta / angle)
	_head.global_basis = Basis(current.slerp(desired, step))
