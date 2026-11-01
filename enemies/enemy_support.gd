class_name EnemySupport
extends Enemy
## Саппорт (№38): небольшой летающий враг. Привязывается к одному врагу, парит над ним и лечит.
## Привязка показана лучом между саппортом и целью в мире (11-UI-design, №50). Когда цель погибла,
## выбирает другую. Пока нет ни одного врага, которому можно помочь, не простаивает, а нападает на игрока (№91):
## подлетает и бьёт в ближнем бою, как летающий; появился союзник — возвращается к лечению (щитовик к барьеру).

const BEAM_THICKNESS: float = 0.06
const BEAM_COLOR: Color = Color(0.4, 1.0, 0.5)
## Ближе этого расстояния до точки парения саппорт считается добравшимся и стоит на месте.
const HOVER_TOLERANCE: float = 0.1
## Как резко саппорт тормозит у точки парения (1/с): скорость не больше расстояния, умноженного на это число.
const HOVER_STIFFNESS: float = 6.0

var ally: Enemy
var _beam: MeshInstance3D
var _attack_cooldown: float = 0.0
var _attack_in_range: bool = false


func is_flier() -> bool:
	return true


func _ready() -> void:
	super._ready()
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = _get_beam_color()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = material
	_beam = MeshInstance3D.new()
	_beam.mesh = mesh
	_beam.top_level = true
	_beam.visible = false
	add_child(_beam)


func _behavior(delta: float, player_or_null: Player) -> void:
	if ally == null or not is_instance_valid(ally) or ally.is_dead:
		ally = _find_ally()
	if ally == null:
		_update_beam(false)
		_attack_player(delta, player_or_null)
		return
	_attack_in_range = false
	var desired: Vector3 = Vector3.ZERO
	var to_point: Vector3 = _hover_point() - global_position
	var distance: float = to_point.length()
	if distance > HOVER_TOLERANCE:
		var speed: float = minf(settings.move_speed * get_speed_multiplier(), distance * HOVER_STIFFNESS)
		desired = to_point / distance * speed
	_face(ally.global_position - global_position)
	_update_beam(_affect_ally(delta))
	# Летает: тяжести нет, на землю не падает.
	velocity = desired
	move_and_slide()


## Нет союзника: летит к точке над игроком и бьёт в ближнем бою (как EnemyFlyer, без охвата и покачивания).
func _attack_player(delta: float, player: Player) -> void:
	_attack_cooldown = maxf(_attack_cooldown - delta, 0.0)
	var desired: Vector3 = Vector3.ZERO
	var close: bool = false
	if player != null:
		var center: Vector3 = player.get_center_position()
		var to_center: float = global_position.distance_to(center)
		if to_center <= settings.aggro_range or always_aggro:
			var to_target: Vector3 = center + Vector3(0.0, settings.fly_height_offset, 0.0) - global_position
			var distance: float = to_target.length()
			_face(_flat_to(player))
			if distance > settings.melee_range * 0.5:
				desired = to_target / distance * settings.move_speed * get_speed_multiplier()
			close = to_center <= settings.melee_range
			if close and not _attack_in_range:
				_attack_cooldown = maxf(_attack_cooldown, settings.melee_cooldown * 0.5)
			if close and _attack_cooldown <= 0.0:
				_attack_cooldown = settings.melee_cooldown
				player.take_damage(settings.melee_damage * damage_scale, global_position)
	_attack_in_range = close
	velocity = desired
	move_and_slide()


## Действие на привязанного врага в этом тике (лечение). Возвращает true, если действует и луч привязки нужно показать.
func _affect_ally(delta: float) -> bool:
	if global_position.distance_to(ally.global_position) <= settings.heal_range:
		ally.heal(settings.heal_per_second * delta)
		return true
	return false


func _get_beam_color() -> Color:
	return BEAM_COLOR


## Подходит ли враг для привязки (щитовик берёт только тех, кого ещё никто не гасит).
func _accepts_ally(_candidate: Enemy) -> bool:
	return true


## Точка парения: над полоской здоровья союзника на заданную высоту.
func _hover_point() -> Vector3:
	return ally.global_position + Vector3(0.0, ally.settings.health_bar_height + settings.hover_height, 0.0)


## Ближайший живой враг (кроме саппортов и себя) в радиусе поиска.
func _find_ally() -> Enemy:
	var best: Enemy = null
	var best_distance: float = settings.search_range
	for node: Node in get_tree().get_nodes_in_group(&"enemies"):
		var candidate: Enemy = node as Enemy
		if candidate == null or candidate == self or candidate is EnemySupport or candidate.is_dead or not _accepts_ally(candidate):
			continue
		var distance: float = candidate.global_position.distance_to(global_position)
		if distance <= best_distance:
			best_distance = distance
			best = candidate
	return best


func _update_beam(active: bool) -> void:
	_beam.visible = active
	if not active:
		return
	var from: Vector3 = global_position
	var to: Vector3 = ally.global_position + Vector3(0.0, ally.settings.health_bar_height * 0.5, 0.0)
	var length: float = from.distance_to(to)
	if length < 0.01:
		_beam.visible = false
		return
	var direction: Vector3 = (to - from) / length
	var up: Vector3 = Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT
	_beam.global_transform = Transform3D(Basis.looking_at(direction, up), from.lerp(to, 0.5))
	_beam.scale = Vector3(BEAM_THICKNESS, BEAM_THICKNESS, length)
