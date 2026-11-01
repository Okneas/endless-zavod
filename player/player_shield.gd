class_name PlayerShield
extends Node
## Щит игрока (№93, как в Borderlands): синяя полоса над здоровьем. Впитывает урон первым, остаток идёт в здоровье; после паузы без урона
## сам восстанавливается. Щит берётся из слота Inventory.shield. Особенности видов срабатывают здесь: нова (взрыв, когда щит упал до нуля),
## шип (поглощённое попадание ранит врагов вплотную) и поглотитель (шанс свести попадание на нет и вернуть щиту часть урона).
## Без щита в слоте (снят) полоса скрыта и весь урон идёт в здоровье.

## Щит изменился: сколько осталось и какова ёмкость (0 и 0, если щита нет).
signal changed(current: float, maximum: float)
## Щит упал до нуля.
signal depleted

var current: float = 0.0
var maximum: float = 0.0
var stats: ShieldInstance.Stats

var _player: Player
var _since_damage: float = 999.0
var _effect_cooldown_left: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func setup(player: Player) -> void:
	_player = player
	_rng.randomize()
	# Новый щит в слоте стоит полным (как в Borderlands); рост уровня ёмкость поднимает, но щит не наполняет.
	Inventory.shield_changed.connect(func() -> void: refresh(true))
	Progress.level_changed.connect(func(_level: int) -> void: refresh(false))
	refresh(true)


## Перечитывает щит из слота. refill: наполнить до краёв (старт, воскрешение); иначе остаток не больше новой ёмкости.
func refresh(refill: bool) -> void:
	var equipped: ShieldInstance = Inventory.shield
	if equipped == null:
		stats = null
		maximum = 0.0
		current = 0.0
	else:
		stats = equipped.compute_stats()
		maximum = stats.capacity
		current = maximum if refill else minf(current, maximum)
	changed.emit(current, maximum)


func has_shield() -> bool:
	return stats != null and maximum > 0.0


## Доля щита 0..1 (0, если щита нет).
func get_ratio() -> float:
	return clampf(current / maximum, 0.0, 1.0) if maximum > 0.0 else 0.0


## Вид особенности щита в слоте (STANDARD, если щита нет).
func get_kind() -> ShieldDefinition.Kind:
	var equipped: ShieldInstance = Inventory.shield
	return equipped.definition.kind if equipped != null else ShieldDefinition.Kind.STANDARD


## Принимает удар: возвращает ту часть урона, которая прошла мимо щита (в здоровье).
func absorb(amount: float) -> float:
	_since_damage = 0.0
	if not has_shield() or current <= 0.0:
		return amount
	var kind: ShieldDefinition.Kind = get_kind()
	# Поглотитель: попадание сводится на нет, щит возвращает часть урона.
	if kind == ShieldDefinition.Kind.ABSORB and _rng.randf() < stats.effect_power:
		current = minf(current + amount * stats.effect_restore, maximum)
		changed.emit(current, maximum)
		return 0.0
	var soaked: float = minf(current, amount)
	current -= soaked
	if kind == ShieldDefinition.Kind.SPIKE and _effect_cooldown_left <= 0.0:
		_effect_cooldown_left = stats.effect_cooldown
		_burst(stats.effect_power, stats.effect_radius)
	changed.emit(current, maximum)
	if current <= 0.0:
		depleted.emit()
		if kind == ShieldDefinition.Kind.NOVA:
			_burst(stats.effect_power, stats.effect_radius)
	return amount - soaked


func _physics_process(delta: float) -> void:
	if _player == null or _player.is_dead or not has_shield():
		return
	_since_damage += delta
	_effect_cooldown_left = maxf(_effect_cooldown_left - delta, 0.0)
	if current >= maximum or _since_damage < stats.recharge_delay:
		return
	current = minf(current + stats.recharge_rate * delta, maximum)
	changed.emit(current, maximum)


# Взрыв вокруг игрока (нова и шип): враги в радиусе получают урон, игрока он не задевает.
func _burst(damage: float, radius: float) -> void:
	var equipped: ShieldInstance = Inventory.shield
	if equipped == null or damage <= 0.0 or radius <= 0.0:
		return
	var origin: Vector3 = _player.get_center_position()
	BlastEffect.spawn(_player.get_parent(), origin, radius, equipped.definition.color)
	Blast.apply(_player, origin, radius, damage, equipped.definition.effect_element, Config.data.shields.effect_edge_share, 0.0, [_player.get_rid()])
