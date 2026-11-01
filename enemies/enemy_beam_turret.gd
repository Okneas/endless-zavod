class_name EnemyBeamTurret
extends Enemy
## Турель-лучемёт (срез 7б, №83): стоит и вращается вокруг своей оси, из неё в beam_count сторон торчат короткие лучи длиной
## beam_length. Луч бьёт игрока, который попал в него, раз в beam_tick_interval на beam_damage. Лучи висят на высоте
## beam_height над ногами турели: через них можно перепрыгнуть, пока луч ниже прыжка, и пробежать мимо, пока они разошлись.
## При beam_active_range больше нуля лучи работают только когда игрок ближе этого, иначе вращаются всегда (по умолчанию 0: радиуса нет).
## Стены останавливают луч (№89): он обрезается по первой преграде мира и за ней не бьёт.

const BEAM_COLOR: Color = Color(1.0, 0.25, 0.2)
const BEAM_IDLE_COLOR: Color = Color(0.45, 0.2, 0.2)
## Игрок для луча это капсула: к ширине луча прибавляется радиус тела.
const PLAYER_RADIUS: float = 0.4
## Слой мира (стены, пол, закрытые двери), который останавливает луч.
const WORLD_MASK: int = 1
## Короче этого луч не делаем: нулевой масштаб ломает расчёт.
const MIN_BEAM_LENGTH: float = 0.05

var _beams: Array[MeshInstance3D] = []
## Текущая длина каждого луча после обрезки по стене, м.
var _lengths: Array[float] = []
var _beam_material: StandardMaterial3D
var _tick_left: float = 0.0
var _spin: float = 0.0

@onready var _head: Node3D = $Head


func _ready() -> void:
	super._ready()
	_beam_material = StandardMaterial3D.new()
	_beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_material.albedo_color = BEAM_COLOR
	for i: int in settings.beam_count:
		var mesh: BoxMesh = BoxMesh.new()
		mesh.size = Vector3(settings.beam_thickness, settings.beam_thickness, settings.beam_length)
		mesh.material = _beam_material
		var beam: MeshInstance3D = MeshInstance3D.new()
		beam.mesh = mesh
		# Луч смотрит в -Z головы и лежит от оси наружу.
		beam.position = Vector3(0.0, 0.0, -settings.beam_length * 0.5)
		var pivot: Node3D = Node3D.new()
		pivot.rotation.y = TAU * float(i) / float(settings.beam_count)
		pivot.add_child(beam)
		_head.add_child(pivot)
		_beams.append(beam)
		_lengths.append(settings.beam_length)
	# Голова на высоте лучей.
	_head.position.y = settings.beam_height


func _behavior(delta: float, player: Player) -> void:
	_spin += deg_to_rad(settings.spin_speed) * delta
	_head.rotation.y = _spin
	_trim_beams()
	_tick_left = maxf(_tick_left - delta, 0.0)
	var active: bool = true
	if settings.beam_active_range > 0.0:
		active = player != null and player.global_position.distance_to(global_position) <= settings.beam_active_range
	_beam_material.albedo_color = BEAM_COLOR if active else BEAM_IDLE_COLOR
	if not active or player == null or _tick_left > 0.0:
		return
	if _beam_hits(player):
		_tick_left = settings.beam_tick_interval
		player.take_damage(settings.beam_damage * damage_scale, _head.global_position)


## Обрезает каждый луч по первой преграде мира: короче и показывается, и бьёт.
func _trim_beams() -> void:
	var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
	var origin: Vector3 = _head.global_position
	for i: int in _beams.size():
		var beam: MeshInstance3D = _beams[i]
		var forward: Vector3 = -beam.get_parent().global_basis.z
		var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(origin, origin + forward * settings.beam_length, WORLD_MASK)
		var hit: Dictionary = space.intersect_ray(query)
		var length: float = settings.beam_length
		if not hit.is_empty():
			length = maxf(origin.distance_to(hit["position"] as Vector3), MIN_BEAM_LENGTH)
		_lengths[i] = length
		beam.position.z = -length * 0.5
		beam.scale.z = length / maxf(settings.beam_length, MIN_BEAM_LENGTH)


## Задевает ли какой-нибудь луч игрока сейчас (положение лучей берётся из вращения головы).
func _beam_hits(player: Player) -> bool:
	var origin: Vector3 = _head.global_position
	var body: CollisionShape3D = player.get_node("CollisionShape3D") as CollisionShape3D
	var capsule: CapsuleShape3D = body.shape as CapsuleShape3D
	var feet: float = player.global_position.y
	# Луч задевает по высоте, если его уровень внутри капсулы игрока.
	if origin.y < feet - settings.beam_thickness * 0.5 or origin.y > feet + capsule.height + settings.beam_thickness * 0.5:
		return false
	var offset: Vector2 = Vector2(player.global_position.x - origin.x, player.global_position.z - origin.z)
	for i: int in _beams.size():
		var forward: Vector3 = -_beams[i].get_parent().global_basis.z
		var direction: Vector2 = Vector2(forward.x, forward.z).normalized()
		var along: float = offset.dot(direction)
		var across: float = absf(offset.cross(direction))
		if along >= -PLAYER_RADIUS and along <= _lengths[i] + PLAYER_RADIUS and across <= settings.beam_thickness * 0.5 + PLAYER_RADIUS:
			return true
	return false
