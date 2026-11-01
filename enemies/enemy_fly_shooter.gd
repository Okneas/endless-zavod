class_name EnemyFlyShooter
extends Enemy
## Летающий стрелок (срез 7б, №83): летает вокруг игрока на preferred_range, не подпуская ближе retreat_range, и стреляет
## снарядами, когда видит игрока и он ближе shoot_range. Над землёй держится на fly_height_offset от центра игрока, боком
## «кружит» (strafe_fraction) и покачивается в полёте. Препятствия по навигации не огибает (как обычный летающий).

const BOB_AMPLITUDE: float = 0.25
const BOB_FREQUENCY: float = 2.2
## Ближе этого расстояния до точки по высоте вертикальная подстройка выключается (иначе враг дрожал бы).
const HEIGHT_TOLERANCE: float = 0.3

var _shots: ShotCycle = ShotCycle.new()
var _time: float = 0.0
var _strafe_sign: float = 1.0
var _strafe_left: float = 0.0

@onready var _muzzle: Marker3D = $Muzzle


func is_flier() -> bool:
	return true


func _behavior(delta: float, player: Player) -> void:
	_time += delta
	var desired: Vector3 = Vector3.ZERO
	var shooting: bool = false
	if player != null:
		var center: Vector3 = player.get_center_position()
		var to_player: Vector3 = center - global_position
		var distance: float = to_player.length()
		if distance <= settings.aggro_range or always_aggro:
			_face(_flat_to(player))
			var speed: float = settings.move_speed * get_speed_multiplier()
			var flat: Vector3 = Vector3(to_player.x, 0.0, to_player.z)
			var flat_distance: float = flat.length()
			var flat_dir: Vector3 = flat / flat_distance if flat_distance > 0.01 else Vector3.ZERO
			if distance > settings.preferred_range + 1.0:
				var approach: Vector3 = to_player + _flank_offset(to_player, distance)
				desired = approach.normalized() * speed
			elif settings.retreat_range > 0.0 and distance < settings.retreat_range:
				desired = -flat_dir * speed
			elif settings.strafe_fraction > 0.0:
				_strafe_left -= delta
				if _strafe_left <= 0.0:
					_strafe_sign = 1.0 if rng.randf() < 0.5 else -1.0
					_strafe_left = settings.strafe_change_time * rng.randf_range(0.6, 1.4)
				desired = Vector3(-flat_dir.z, 0.0, flat_dir.x) * _strafe_sign * speed * settings.strafe_fraction
			# Высота: держится на заданной высоте над центром игрока, не прижимаясь к нему вплотную.
			var height_error: float = (center.y + settings.fly_height_offset) - global_position.y
			if absf(height_error) > HEIGHT_TOLERANCE:
				desired.y = clampf(height_error * 2.0, -speed, speed)
			shooting = distance <= settings.shoot_range and _line_of_sight(_muzzle.global_position, center)
			if _shots.update(delta, shooting, settings):
				_shoot_projectile(_muzzle.global_position, center)
	if not shooting:
		_shots.reset()
	velocity = desired
	velocity.y += cos(_time * BOB_FREQUENCY) * BOB_AMPLITUDE * BOB_FREQUENCY
	move_and_slide()
