class_name EnemyBomber
extends Enemy
## Летающий камикадзе (срез 7б, №83). Летит к игроку, на charge_range останавливается и заряжается (замах с миганием), затем
## стремительно летит в точку, где стоял игрок в конце замаха (это не самонаведение: уклониться можно), и взрывается при
## достижении точки, упоре в препятствие или близости к игроку. Взрыв бьёт по площади explosion_radius. Взорвавшийся враг
## наград не даёт; убитый игроком до взрыва награду даёт как обычно.

enum Phase { APPROACH, WINDUP, CHARGE }

const BOB_AMPLITUDE: float = 0.25
const BOB_FREQUENCY: float = 2.2
## Рывок кончается взрывом, когда до точки цели ближе этого или до игрока ближе CONTACT_DISTANCE.
const TARGET_REACHED_DISTANCE: float = 0.8
const CONTACT_DISTANCE: float = 1.1
const EXPLOSION_COLOR: Color = Color(1.0, 0.5, 0.15, 0.55)
const EXPLOSION_FADE_TIME: float = 0.3

var phase: Phase = Phase.APPROACH
var exploded: bool = false

var _time: float = 0.0
var _phase_left: float = 0.0
var _charge_target: Vector3 = Vector3.ZERO
var _charge_direction: Vector3 = Vector3.ZERO


func is_flier() -> bool:
	return true


func _gives_rewards() -> bool:
	return not exploded


func _behavior(delta: float, player: Player) -> void:
	_time += delta
	match phase:
		Phase.APPROACH:
			_approach(delta, player)
		Phase.WINDUP:
			_windup(delta, player)
		Phase.CHARGE:
			_charge(delta, player)


func _approach(_delta: float, player: Player) -> void:
	var desired: Vector3 = Vector3.ZERO
	if player != null:
		var center: Vector3 = player.get_center_position()
		var distance: float = center.distance_to(global_position)
		var to_target: Vector3 = center + Vector3(0.0, settings.fly_height_offset, 0.0) + _flank_offset(center - global_position, distance) - global_position
		if distance <= settings.aggro_range or always_aggro:
			_face(_flat_to(player))
			if distance <= settings.charge_range and _line_of_sight(global_position, center):
				phase = Phase.WINDUP
				_phase_left = settings.charge_windup
				telegraph_amount = 1.0
			elif to_target.length() > 0.2:
				desired = to_target.normalized() * settings.move_speed * get_speed_multiplier()
	velocity = desired
	velocity.y += cos(_time * BOB_FREQUENCY) * BOB_AMPLITUDE * BOB_FREQUENCY
	move_and_slide()


func _windup(delta: float, player: Player) -> void:
	_phase_left -= delta
	velocity = Vector3.ZERO
	move_and_slide()
	if player != null:
		_face(_flat_to(player))
	if _phase_left > 0.0:
		return
	# Точка рывка фиксируется в конце замаха: игрок успевает уйти с неё.
	_charge_target = player.get_center_position() if player != null else global_position + (-global_basis.z) * settings.charge_range
	_charge_direction = (_charge_target - global_position).normalized()
	phase = Phase.CHARGE
	_phase_left = settings.charge_max_time
	telegraph_amount = 0.0


func _charge(delta: float, player: Player) -> void:
	_phase_left -= delta
	var to_target: Vector3 = _charge_target - global_position
	var step: float = settings.charge_speed * delta
	velocity = _charge_direction * settings.charge_speed
	move_and_slide()
	var blocked: bool = get_slide_collision_count() > 0
	var arrived: bool = to_target.length() <= maxf(TARGET_REACHED_DISTANCE, step) or to_target.dot(_charge_direction) <= 0.0
	var contact: bool = player != null and player.get_center_position().distance_to(global_position) <= CONTACT_DISTANCE
	if blocked or arrived or contact or _phase_left <= 0.0:
		explode(player)


## Взрыв: урон игроку внутри explosion_radius и вспышка. Враг гибнет без награды.
func explode(player: Player = null) -> void:
	if exploded or is_dead:
		return
	exploded = true
	telegraph_amount = 0.0
	var parent: Node = get_parent()
	if player == null:
		player = _get_player()
	if player != null and not player.is_dead and player.get_center_position().distance_to(global_position) <= settings.explosion_radius:
		player.take_damage(settings.explosion_damage * damage_scale, global_position)
	_spawn_explosion_visual(parent)
	_lose_health(health)


# Расширяющаяся полупрозрачная сфера, быстро гаснущая; живёт сама, пока не растворится.
func _spawn_explosion_visual(parent: Node) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = EXPLOSION_COLOR
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.material = material
	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.mesh = mesh
	parent.add_child(visual)
	visual.global_position = global_position
	visual.scale = Vector3.ONE * 0.3
	var tween: Tween = visual.create_tween()
	tween.set_parallel(true)
	tween.tween_property(visual, "scale", Vector3.ONE * settings.explosion_radius, EXPLOSION_FADE_TIME)
	tween.tween_property(material, "albedo_color:a", 0.0, EXPLOSION_FADE_TIME)
	tween.chain().tween_callback(visual.queue_free)
