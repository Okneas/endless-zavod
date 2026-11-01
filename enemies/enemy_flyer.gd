class_name EnemyFlyer
extends Enemy
## Летающий (№38): мало здоровья, преследует игрока в воздухе и бьёт в ближнем бою.
## Летит прямо к точке над игроком, препятствия не огибает (навигация позже, срез 6).

## Покачивание в полёте (оформление): амплитуда и частота.
const BOB_AMPLITUDE: float = 0.25
const BOB_FREQUENCY: float = 2.2

var _cooldown: float = 0.0
var _in_range: bool = false
var _time: float = 0.0


func is_flier() -> bool:
	return true


func _behavior(delta: float, player: Player) -> void:
	_time += delta
	_cooldown = maxf(_cooldown - delta, 0.0)
	var desired: Vector3 = Vector3.ZERO
	if player != null:
		var target: Vector3 = player.get_center_position() + Vector3(0.0, settings.fly_height_offset, 0.0)
		target += _flank_offset(target - global_position, global_position.distance_to(player.get_center_position()))
		var to_target: Vector3 = target - global_position
		var distance: float = to_target.length()
		var to_center: float = global_position.distance_to(player.get_center_position())
		if to_center <= settings.aggro_range or always_aggro:
			_face(_flat_to(player))
			if distance > settings.melee_range * 0.5:
				desired = to_target / distance * settings.move_speed * get_speed_multiplier()
			var close: bool = to_center <= settings.melee_range
			if close and not _in_range:
				_cooldown = maxf(_cooldown, settings.melee_cooldown * 0.5)
			_in_range = close
			if close and _cooldown <= 0.0:
				_cooldown = settings.melee_cooldown
				player.take_damage(settings.melee_damage * damage_scale, global_position)
		else:
			_in_range = false
	else:
		_in_range = false
	velocity = desired
	velocity.y += cos(_time * BOB_FREQUENCY) * BOB_AMPLITUDE * BOB_FREQUENCY
	move_and_slide()
