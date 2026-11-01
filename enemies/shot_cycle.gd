class_name ShotCycle
extends RefCounted
## Ритм стрельбы врага-стрелка: прицеливание после того, как увидел игрока, очередь из burst_count пуль, пауза до следующей.
## Числа берутся из EnemySettings (aim_time, burst_count, burst_shot_interval, shoot_interval). Сама стрельба снаружи:
## update() только говорит, пора ли выпускать пулю в этом тике.

var _aim_left: float = -1.0
var _cooldown: float = 0.0
var _burst_left: int = 0
var _gap_left: float = 0.0


## active: враг видит цель и может стрелять. Возвращает true, если в этом тике нужно выпустить одну пулю.
func update(delta: float, active: bool, settings: EnemySettings) -> bool:
	_cooldown = maxf(_cooldown - delta, 0.0)
	if not active:
		reset()
		return false
	if _aim_left < 0.0:
		_aim_left = settings.aim_time
	# Не уходит ниже нуля: отрицательное значение значит «ещё не начинал целиться».
	_aim_left = maxf(_aim_left - delta, 0.0)
	if _burst_left > 0:
		_gap_left -= delta
		if _gap_left <= 0.0:
			_burst_left -= 1
			_gap_left = settings.burst_shot_interval
			return true
		return false
	if _aim_left <= 0.0 and _cooldown <= 0.0:
		var extra: int = maxi(settings.burst_count - 1, 0)
		_cooldown = maxf(settings.shoot_interval, float(extra) * settings.burst_shot_interval)
		_burst_left = extra
		_gap_left = settings.burst_shot_interval
		return true
	return false


## Потерял цель: следующий раз прицеливание начнётся заново (пауза между очередями при этом не сбрасывается).
func reset() -> void:
	_aim_left = -1.0
	_burst_left = 0
