class_name EnemyGunner
extends EnemyChaser
## Преследующий стрелок (срез 7б, №83): ходит за игроком по земле (навигация та же, что у преследующего), с
## preferred_range останавливается и стреляет одиночными снарядами в меру частыми выстрелами. Пока стреляет, шагает
## боком (strafe_fraction), как бандиты в Borderlands. Если игрока не видно, подходит ближе. В ближнем бою не бьёт.

var _shots: ShotCycle = ShotCycle.new()
var _strafe_sign: float = 1.0
var _strafe_left: float = 0.0

@onready var _muzzle: Marker3D = $Muzzle


func _behavior(delta: float, player: Player) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)
	var velocity_flat: Vector3 = Vector3.ZERO
	var shooting: bool = false
	if player != null:
		var flat: Vector3 = _flat_to(player)
		var distance: float = flat.length()
		if distance <= settings.aggro_range or always_aggro:
			_face(flat)
			var target: Vector3 = player.get_center_position()
			var sees: bool = distance <= settings.shoot_range and _line_of_sight(_muzzle.global_position, target)
			var speed: float = settings.move_speed * get_speed_multiplier() * speed_multiplier
			if distance > settings.preferred_range or not sees:
				velocity_flat = _walk_direction(player, flat, distance, delta) * speed
			elif settings.strafe_fraction > 0.0:
				_strafe_left -= delta
				if _strafe_left <= 0.0:
					_strafe_sign = 1.0 if rng.randf() < 0.5 else -1.0
					_strafe_left = settings.strafe_change_time * rng.randf_range(0.6, 1.4)
				velocity_flat = Vector3(-flat.z, 0.0, flat.x).normalized() * _strafe_sign * speed * settings.strafe_fraction
			shooting = sees
			if _shots.update(delta, shooting, settings):
				_shoot_projectile(_muzzle.global_position, target)
	if not shooting:
		_shots.reset()
	if movement_locked:
		velocity_flat = Vector3.ZERO
	_move_ground(velocity_flat, delta)
